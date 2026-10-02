/// DNI-476 (Story 1.14) AC-5: [FirestoreAddTrackActionRepository] writes
/// "Add track" as ONE named governed action — one change-log entry per
/// entity, all sharing one `action_id`, each entity's docs and entry in a
/// self-contained batch of at most 10 governed docs, in action order — and
/// a failed batch is retried with the identical ids.
///
/// Runs the real repositories and governed commands on a fake Firestore
/// (`FirestoreGovernedWriter`).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/add_track_action_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/firestore_fake.dart';
import '../../../../../helpers/firestore_governed_writer.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'add-track-uid';
const _profileId = governedTestProfileId;
const _c = CurriculumId.mishnayos;

List<StageDefinition> _stages(int n) => [
  for (var i = 1; i <= n; i++)
    StageDefinition(
      curriculumId: _c,
      stageOrder: i,
      stageName: 'Stage $i',
      delayDays: i - 1,
      isDefault: false,
    ),
];

const _allDays = {
  1: DayType.study,
  2: DayType.study,
  3: DayType.study,
  4: DayType.study,
  5: DayType.study,
  6: DayType.review,
  7: DayType.study,
};

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGovernedWriter writer;
  late ProviderContainer container;
  late AddTrackActionRepository repo;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    writer = FirestoreGovernedWriter(firestore, uid: _uid);
    container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => AccountFirebaseHandles(
            app: _MockFirebaseApp(),
            firestore: firestore,
            auth: _MockFirebaseAuth(),
            uid: _uid,
          ),
        ),
        ownerGovernedWriterProvider.overrideWithValue(writer),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    repo = container.read(
      Provider<AddTrackActionRepository>(
        (ref) => FirestoreAddTrackActionRepository(
          ref: ref,
          clock: () => governedTestNow,
        ),
      ),
    );
  });

  Future<List<ChangeLogEntry>> entriesOf(String actionId) async => [
    for (final e in await writer.entries())
      if (e.actionId == actionId) e,
  ];

  test('one action: an entry per entity, all sharing the action id, in '
      'action order', () async {
    final actionId = await repo.applyAddTrack(
      AddTrackPlan(
        curriculumId: _c,
        stages: _stages(3),
        studyDays: _allDays,
        scopes: const [(level: 1, value: 'Seder Zeraim')],
        goal: GoalEntity(
          curriculumId: _c,
          goalType: 'deadline',
          targetDate: DateTime.utc(2027, 6, 1),
          description: 'Siyum',
          createdAt: governedTestNow,
          updatedAt: governedTestNow,
        ),
      ),
    );

    final result = writer.results.single as CaptureSuccess;
    expect(actionId, result.actionId);
    final entries = await entriesOf(actionId!);
    final byId = {for (final e in entries) e.id: e};
    expect(
      [for (final id in result.changeIds) byId[id]!.entity],
      [
        GovernedEntity.mainTrack,
        GovernedEntity.mainTrackStages,
        GovernedEntity.mainTrackStudyDays,
        GovernedEntity.mainTrackScope,
        GovernedEntity.goal,
      ],
    );
    expect(result.changeIds.first, actionId);
    // Batches were committed in action order, one per entity.
    expect(writer.changeLog.attempts, result.changeIds);
    // Every written governed doc carries its entity's entry id.
    for (final e in entries) {
      for (final key in e.changedKeys) {
        final doc = await writer.doc(key.collection, key.docId);
        expect(doc?['last_change_id'], e.id, reason: key.key);
      }
    }
  });

  test(
    'every batch holds at most 10 governed docs and is self-contained',
    () async {
      await repo.applyAddTrack(
        AddTrackPlan(
          curriculumId: _c,
          stages: _stages(4),
          studyDays: _allDays,
          scopes: [for (var i = 0; i < 10; i++) (level: 2, value: 'M$i')],
        ),
      );
      final action = writer.actions.single;
      for (final change in action.changes) {
        expect(change.docs.length, lessThanOrEqualTo(10), reason: '$change');
        expect(change.docs.map((d) => d.collection).toSet(), {
          change.entity.collection,
        });
      }
      expect(writer.oversized.requests, isEmpty);
    },
  );

  test('an oversized Add track with a new goal goes online as one action '
      'the callable accepts (its field specs allow every key sent)', () async {
    final actionId = await repo.applyAddTrack(
      AddTrackPlan(
        curriculumId: _c,
        // 11 stages: one entity over the 10-doc budget sends the whole
        // action through the online-only callable.
        stages: _stages(11),
        studyDays: _allDays,
        goal: GoalEntity(
          curriculumId: _c,
          goalType: 'deadline',
          targetDate: DateTime.utc(2027, 6, 1),
          description: 'Siyum',
          dateType: 'hebrew',
          createdAt: governedTestNow,
          updatedAt: governedTestNow,
        ),
      ),
    );

    final request = writer.oversized.requests.single;
    expect(actionId, request.actionId);
    expect(writer.results.single, isA<CaptureSuccess>());
    expect([
      for (final e in request.entries) e.change.entity,
    ], containsAllInOrder([GovernedEntity.mainTrack, GovernedEntity.goal]));
    final goal = await writer.doc('goals', 'mishnayos_deadline');
    expect(goal?['description'], 'Siyum');
    expect(goal?['date_type'], 'hebrew');
    expect(goal?['target_date'], '2027-06-01');
    expect(
      (await writer.doc('curriculum_tracks', 'mishnayos'))?['state'],
      'active',
    );
  });

  test('a calendar-program track: the program is set and no goal is '
      'written (AD-43: the calendar sets the pace)', () async {
    await repo.applyAddTrack(
      AddTrackPlan(
        curriculumId: _c,
        stages: _stages(1),
        studyDays: _allDays,
        program: AddTrackProgram(
          programId: 3,
          trackingStartDate: DateTime.utc(2026, 9, 1),
          trackingStartRef: 'Mishnah Berakhot 1:1',
        ),
        goal: GoalEntity(
          curriculumId: _c,
          goalType: 'deadline',
          targetDate: DateTime.utc(2027, 6, 1),
          createdAt: governedTestNow,
          updatedAt: governedTestNow,
        ),
      ),
    );
    expect(writer.results.single, isA<CaptureSuccess>());
    expect(
      (await writer.doc('profile_programs', 'mishnayos'))?['program_id'],
      '3',
    );
    expect(await writer.doc('goals', 'mishnayos_deadline'), isNull);
  });

  test('a batch the server refuses becomes a pending failure whose retry '
      're-sends the identical entry (same id and action id)', () async {
    writer.changeLog.failOnce.add(GovernedEntity.mainTrackStudyDays);

    final actionId = await repo.applyAddTrack(
      AddTrackPlan(curriculumId: _c, stages: _stages(2), studyDays: _allDays),
    );

    final pending = await writer.commands.watchPendingFailures().first;
    final failed = pending.single;
    expect(await writer.doc('study_day_configs', 'mishnayos_1'), isNull);

    final retried = await writer.commands.retry(failed.id);

    expect(retried, isA<CaptureSuccess>());
    expect(
      writer.changeLog.attempts.where((id) => id == failed.id),
      hasLength(2),
    );
    final entry = (await writer.entries()).firstWhere((e) => e.id == failed.id);
    expect(entry.actionId, actionId);
    expect(entry.entity, GovernedEntity.mainTrackStudyDays);
    expect(
      (await writer.doc('study_day_configs', 'mishnayos_1'))?['last_change_id'],
      failed.id,
    );
  });

  test(
    're-adding a removed curriculum clears ended_at in the same action',
    () async {
      await repo.applyAddTrack(
        AddTrackPlan(curriculumId: _c, stages: _stages(1), studyDays: _allDays),
      );
      await firestore
          .doc(
            'users/$_uid/learner_profiles/$_profileId/curriculum_tracks/mishnayos',
          )
          .update({'ended_at': DateTime.utc(2026, 9, 5)});

      final actionId = await repo.applyAddTrack(
        AddTrackPlan(curriculumId: _c, stages: _stages(1), studyDays: _allDays),
      );

      final track = await writer.doc('curriculum_tracks', 'mishnayos');
      expect(track?['ended_at'], isNull);
      final main = (await entriesOf(
        actionId!,
      )).firstWhere((e) => e.entity == GovernedEntity.mainTrack);
      expect(main.after.keys, contains('curriculum_tracks/mishnayos.ended_at'));
    },
  );

  test('not ready: no account throws and writes nothing', () async {
    final bare = ProviderContainer(
      overrides: [ownerGovernedWriterProvider.overrideWithValue(writer)],
    );
    addTearDown(bare.dispose);
    final notReady = bare.read(
      Provider<AddTrackActionRepository>(
        (ref) => FirestoreAddTrackActionRepository(ref: ref),
      ),
    );
    await expectLater(
      notReady.applyAddTrack(
        AddTrackPlan(curriculumId: _c, stages: _stages(1), studyDays: _allDays),
      ),
      throwsA(isA<AddTrackNotReadyException>()),
    );
    expect(writer.results, isEmpty);
  });
}
