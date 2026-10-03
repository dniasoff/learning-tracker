/// Unit tests for `lib/data/repositories/firestore_goal_repository.dart`
/// (DNI-476 / Story 1.14): goals are the AD-38 governed entity `goal` at
/// the AD-43 fixed ids, and every write goes through the governed commands
/// (`FirestoreGovernedWriter`: the real commands and change-log repository
/// on a fake Firestore). Covers the fixed ids, field-level merges with a
/// co-written `change_log` entry, a mode switch as one two-entity action,
/// tombstones instead of deletes, the calendar-program rejection, and the
/// read side (ended docs skipped, null-first sort, decode leniency).
///
/// `fake_cloud_firestore` does not evaluate the owner rules; those are
/// covered by the emulator rules suite (`make test-rules`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_governed_writer.dart';

const _uid = 'uid-1';
const _profileId = governedTestProfileId;

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGovernedWriter writer;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    writer = FirestoreGovernedWriter(firestore, uid: _uid);
  });

  CollectionReference<Map<String, dynamic>> goals() => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('goals');

  FirestoreGoalRepository buildRepo({OwnerGovernedWriter? using}) =>
      FirestoreGoalRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
        writer: using ?? writer,
        clock: () => governedTestNow,
      );

  group('AD-43 fixed ids and governed writes', () {
    test('a deadline goal is goals/{c}_deadline, written with its entry and '
        'last_change_id', () async {
      final repo = buildRepo();
      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        description: 'Siyum',
      );

      final entries = await writer.entries();
      final entry = entries.single;
      expect(entry.entity, GovernedEntity.goal);
      expect(entry.entityId, 'mishnayos_deadline');
      final doc = (await writer.doc('goals', 'mishnayos_deadline'))!;
      expect(doc, {
        'goal_type': 'deadline',
        'target_date': '2027-06-01',
        'description': 'Siyum',
        'date_type': 'gregorian',
        'curriculum_id': 'mishnayos',
        'created_at': governedTestNow.toIso8601String(),
        'last_change_id': entry.id,
      });
      expect(doc.keys, isNot(contains('updated_at')));
      expect(doc.keys, isNot(contains('target_percent')));
    });

    test('a pace goal is goals/{c}_pace with its pace fields', () async {
      final repo = buildRepo();
      await repo.createGoal(
        curriculumId: CurriculumId.bavli,
        paceTarget: const PacePeriodTarget(rate: 2, period: 'per_day'),
        paceGranularity: PaceGranularity.daf,
      );
      final doc = (await writer.doc('goals', 'bavli_pace'))!;
      expect(doc['goal_type'], 'pace');
      expect(doc['pace_value'], 2);
      expect(doc['pace_unit'], 'per_day');
      expect(doc['pace_granularity'], 'daf');
    });

    test('a second create of the same kind updates the same doc and logs only '
        'the changed fields', () async {
      final repo = buildRepo();
      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
      );
      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 9, 1)),
      );

      expect((await goals().get()).docs.map((d) => d.id), [
        'mishnayos_deadline',
      ]);
      final second = (await writer.lastEntries()).single;
      expect(second.after, {
        'goals/mishnayos_deadline.target_date': '2027-09-01',
      });
    });

    test('switching deadline to pace ends the deadline doc and sets the pace '
        'doc in ONE action (shared action_id)', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
      );
      await repo.updateGoal(
        goal: created,
        paceTarget: const PacePeriodTarget(rate: 3, period: 'per_week'),
      );

      final action = writer.actions.last;
      expect(action.changes.map((c) => c.entityId), [
        'mishnayos_pace',
        'mishnayos_deadline',
      ]);
      final result = writer.results.last as CaptureSuccess;
      expect(result.changeIds, hasLength(2));
      final entries = await writer.entries();
      final actionEntries = entries.where((e) => e.actionId == result.actionId);
      expect(actionEntries, hasLength(2));
      expect(
        (await writer.doc('goals', 'mishnayos_deadline'))!['ended_at'],
        isA<Timestamp>(),
      );
      final live = await repo.getGoals(CurriculumId.mishnayos);
      expect(live.single.goalType, 'pace');
    });

    test('a none goal ends the live goal and writes no goal doc', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: const PacePeriodTarget(rate: 1, period: 'per_day'),
      );
      await repo.updateGoal(goal: created, clearPaceTarget: true);

      expect(await repo.getGoals(CurriculumId.mishnayos), isEmpty);
      expect((await goals().get()).docs.map((d) => d.id), ['mishnayos_pace']);
    });

    test('updateGoal keeps unrelated fields (field-level merge)', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
      );
      await goals().doc('mishnayos_deadline').set({
        'legacy_marker': 'kept',
      }, SetOptions(merge: true));
      await repo.updateGoal(goal: created, description: 'New');

      final doc = (await writer.doc('goals', 'mishnayos_deadline'))!;
      expect(doc['description'], 'New');
      expect(doc['legacy_marker'], 'kept');
      expect(doc['target_date'], '2027-06-01');
    });
  });

  group('removal is a tombstone, never a delete', () {
    test(
      'deleteGoal sets ended_at through a logged change; reads skip it',
      () async {
        final repo = buildRepo();
        final created = await repo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        );
        await repo.deleteGoal(created);

        final doc = (await writer.doc('goals', 'mishnayos_deadline'))!;
        expect(doc['ended_at'], isA<Timestamp>());
        final last = (await writer.lastEntries()).single;
        expect(last.after.keys, ['goals/mishnayos_deadline.ended_at']);
        expect(doc['last_change_id'], last.id);
        expect(await repo.getGoals(CurriculumId.mishnayos), isEmpty);
      },
    );

    test('recreating an ended goal revives the same doc', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
      );
      await repo.deleteGoal(created);
      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        paceTarget: DeadlineTarget(DateTime.utc(2027, 7, 1)),
      );
      final live = await repo.getGoals(CurriculumId.mishnayos);
      expect(live.single.targetDate, DateTime.utc(2027, 7, 1));
      expect((await goals().get()).docs, hasLength(1));
    });

    test('deleting a none goal writes nothing', () async {
      final repo = buildRepo();
      await repo.deleteGoal(
        GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'none',
          createdAt: governedTestNow,
        ),
      );
      expect(writer.actions, isEmpty);
    });
  });

  group('validation and readiness', () {
    test('a goal on a calendar-program curriculum is rejected before any '
        'write', () async {
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('profile_programs')
          .doc('bavli')
          .set({'curriculum_id': 'bavli', 'program_id': 'daf_yomi'});
      final repo = buildRepo();

      await expectLater(
        repo.createGoal(
          curriculumId: CurriculumId.bavli,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        ),
        throwsA(
          isA<GovernedWriteRejectedException>().having(
            (e) => e.result,
            'result',
            const CaptureResult.rejected(CaptureRejection.invalid),
          ),
        ),
      );
      expect((await goals().get()).docs, isEmpty);
      expect(await writer.entries(), isEmpty);
    });

    test('with no writer, a write throws and nothing is written', () async {
      final repo = FirestoreGoalRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      await expectLater(
        repo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          paceTarget: DeadlineTarget(DateTime.utc(2027, 6, 1)),
        ),
        throwsA(isA<GovernedWriterNotReadyException>()),
      );
      expect((await goals().get()).docs, isEmpty);
    });
  });

  group('reads', () {
    test(
      'null target_date first, then ascending; ended docs skipped',
      () async {
        await goals().doc('mishnayos_pace').set({
          'curriculum_id': 'mishnayos',
          'goal_type': 'pace',
          'pace_value': 1,
          'pace_unit': 'per_day',
        });
        await goals().doc('mishnayos_deadline').set({
          'curriculum_id': 'mishnayos',
          'goal_type': 'deadline',
          'target_date': '2027-06-01',
        });
        await goals().doc('legacy_old').set({
          'curriculum_id': 'mishnayos',
          'goal_type': 'deadline',
          'target_date': '2026-01-01',
          'ended_at': Timestamp.fromDate(governedTestNow),
        });

        final read = await buildRepo().getGoals(CurriculumId.mishnayos);
        expect(read.map((g) => g.goalType), ['pace', 'deadline']);
        expect(read.last.targetDate, DateTime.utc(2027, 6, 1));
      },
    );

    test('watchGoals skips ended docs', () async {
      await goals().doc('mishnayos_deadline').set({
        'curriculum_id': 'mishnayos',
        'goal_type': 'deadline',
        'target_date': '2027-06-01',
        'ended_at': Timestamp.fromDate(governedTestNow),
      });
      final first = await buildRepo().watchGoals(CurriculumId.mishnayos).first;
      expect(first, isEmpty);
    });

    test('a malformed document is skipped, not the whole list', () async {
      await goals().doc('bad').set({'curriculum_id': 'mishnayos'});
      await goals().doc('mishnayos_deadline').set({
        'curriculum_id': 'mishnayos',
        'goal_type': 'deadline',
        'target_date': 'not-a-date',
      });
      await goals().doc('mishnayos_pace').set({
        'curriculum_id': 'mishnayos',
        'goal_type': 'pace',
        'pace_value': 1,
        'pace_unit': 'per_day',
      });
      final read = await buildRepo().getGoals(CurriculumId.mishnayos);
      expect(read.map((g) => g.goalType), containsAll(<String>['pace']));
    });

    test('a legacy ISO target_date still decodes', () async {
      await goals().doc('legacy').set({
        'curriculum_id': 'mishnayos',
        'goal_type': 'deadline',
        'target_date': '2027-06-01T00:00:00.000Z',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      });
      final goal = (await buildRepo().getGoals(CurriculumId.mishnayos)).single;
      expect(goal.targetDate, DateTime.utc(2027, 6, 1));
      expect(goal.createdAt, DateTime.utc(2026));
      // R16: a legacy updated_at is ignored on decode.
      expect(goal.toFirestore(), isNot(contains('updated_at')));
    });
  });
}
