// S2 — Serialization parity tests (Task B).
//
// Verifies that the payload each entity kind sends to the CF invoker contains
// the exact field names (and doc-id convention) that the parent-side merger /
// codec reads on pull.
//
// For each entity kind:
//   1. Build a representative payload (as goal_repository_impl / service code
//      would supply it).
//   2. Feed it through a tutored TutoredWriteRouter.
//   3. Assert the CF invoker received the expected field names + doc-id.
//
// R2-H1 fix: GoalEntity now has a trackId field and toFirestore() emits
// track_id when set. GoalMerger no longer silently skips all goal rows.

@Tags(['s2', 'tutor_mode', 'parity', 'serialization'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tutoring/data/routers/tutored_write_router.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

// ── Fake infra ────────────────────────────────────────────────────────────────

class _InvokerRecord {
  final List<({String fn, Map<String, dynamic> args})> calls = [];
  Future<void> call(String fn, Map<String, dynamic> args) async =>
      calls.add((fn: fn, args: Map<String, dynamic>.from(args)));
}

class _NoopDelegate implements SyncWriteFacade {
  @override
  Future<void> pushGoal(Map<String, dynamic> g) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> p) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> d) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> p) async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> b) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> s) async {}
  @override
  Future<void> pushGamificationSettingsSnapshot() async {}
  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> p) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

const _sel = TutoredProfileSelection(
  profileId: '99',
  ownerUid: 'parent_uid',
  grantId: 'grant_001',
  permissions: TutorPermissions(
    canViewProgress: true,
    canViewContent: true,
    canBulkPriorCompletion: true,
    canResetCompletion: true,
    canEditGoals: true,
    canEditStages: true,
    canEditRewards: true,
    canEditStudyDays: true,
    canEditPoints: true,
  ),
);

TutoredWriteRouter _router(_InvokerRecord record) => TutoredWriteRouter(
  delegate: _NoopDelegate(),
  writeService: TutorWriteService(invoker: record.call),
  selection: _sel,
);

void main() {
  // ── Track parity ──────────────────────────────────────────────────────────────
  //
  // TrackConfigMerger reads via TrackCodec.decode:
  //   curriculum_id, state, activated_at, state_changed_at, pace_reset_date.
  // Router passes TrackData through unchanged; doc-id = curriculum_id.

  group('Track parity — tutorUpsertTrack payload matches TrackCodec', () {
    test(
      'track payload has snake_case fields merger reads; docId = curriculum_id',
      () async {
        final record = _InvokerRecord();
        final router = _router(record);

        final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
        final payload = {
          'curriculum_id': 'mishnayos',
          'state': 'active',
          'activated_at': now.toIso8601String(),
          'state_changed_at': now.toIso8601String(),
        };

        await router.pushCurriculumTrack(payload);

        expect(record.calls, hasLength(1));
        final call = record.calls.first;
        expect(call.fn, 'tutorUpsertTrack');
        final args = call.args;

        final trackData = args['trackData'] as Map<String, dynamic>;
        expect(
          trackData['curriculum_id'],
          'mishnayos',
          reason: 'TrackCodec.decode reads curriculum_id',
        );
        expect(
          trackData['state'],
          'active',
          reason: 'TrackCodec.decode reads state',
        );
        expect(
          trackData['activated_at'],
          now.toIso8601String(),
          reason: 'TrackCodec.decode reads activated_at',
        );
        expect(
          trackData['state_changed_at'],
          now.toIso8601String(),
          reason: 'TrackCodec.decode reads state_changed_at (LWW timestamp)',
        );

        // Doc-id derived by the router from curriculum_id.
        expect(
          args['trackId'],
          'mishnayos',
          reason:
              'router uses curriculum_id as trackId, matching Firestore doc path',
        );
      },
    );
  });

  // ── Stage parity ──────────────────────────────────────────────────────────────
  //
  // StageDefinitionMerger reads via StageDefinitionCodec.decode:
  //   curriculum_id, track_id, stage_order, stage_name, schedule, is_default,
  //   updated_at.
  // Router enriches each stage with track_id + curriculum_id + updated_at before
  // calling the CF; stageId = "{trackId}_{stageOrder}".

  group(
    'Stage parity — tutorUpsertStageDefinition payload matches StageDefinitionCodec',
    () {
      test(
        'enriched stage payload has all codec fields; stageId = trackId_stageOrder',
        () async {
          final record = _InvokerRecord();
          final router = _router(record);

          final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
          final stage = {
            'stage_order': 1,
            'stage_name': 'Learn',
            'schedule': '{"type":"delay","delay_days":0}',
            'is_default': true,
          };

          await router.pushStageDefinitions(
            trackId: 7,
            curriculumId: 'mishnayos',
            stages: [stage],
            updatedAt: now,
          );

          expect(record.calls, hasLength(1));
          final call = record.calls.first;
          expect(call.fn, 'tutorUpsertStageDefinition');
          final args = call.args;

          final stageData = args['stageData'] as Map<String, dynamic>;
          expect(
            stageData['curriculum_id'],
            'mishnayos',
            reason: 'StageDefinitionCodec reads curriculum_id',
          );
          expect(
            stageData['track_id'],
            7,
            reason: 'StageDefinitionCodec reads track_id',
          );
          expect(
            stageData['stage_order'],
            1,
            reason: 'StageDefinitionCodec reads stage_order',
          );
          expect(
            stageData['stage_name'],
            'Learn',
            reason: 'StageDefinitionCodec reads stage_name',
          );
          expect(
            stageData['schedule'],
            '{"type":"delay","delay_days":0}',
            reason: 'StageDefinitionCodec reads schedule (JSON)',
          );
          expect(
            stageData['is_default'],
            true,
            reason: 'StageDefinitionCodec reads is_default',
          );
          expect(
            stageData['updated_at'],
            now.toIso8601String(),
            reason: 'StageDefinitionMerger uses updated_at as LWW timestamp',
          );

          // Doc-id.
          expect(
            args['stageId'],
            '7_1',
            reason:
                'stageId = {trackId}_{stageOrder} matches plan doc-id convention',
          );
        },
      );
    },
  );

  // ── StudyDay parity ───────────────────────────────────────────────────────────
  //
  // StudyDayConfigMerger reads via StudyDayConfigCodec.decode:
  //   profile_id, curriculum_id, track_id, day_of_week, day_type, updated_at.
  // Doc-id = "{curriculum_id}_{day_of_week}_{track_id}".

  group(
    'StudyDay parity — tutorUpsertStudyDayConfig payload matches StudyDayConfigCodec',
    () {
      test(
        'payload has all codec fields; configId = curriculum_day_track',
        () async {
          final record = _InvokerRecord();
          final router = _router(record);

          final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
          final payload = {
            'profile_id': 99,
            'curriculum_id': 'mishnayos',
            'track_id': 7,
            'day_of_week': 1,
            'day_type': 'study',
            'updated_at': now.toIso8601String(),
          };

          await router.pushStudyDayConfig(payload);

          expect(record.calls, hasLength(1));
          final call = record.calls.first;
          expect(call.fn, 'tutorUpsertStudyDayConfig');
          final args = call.args;

          final configData = args['configData'] as Map<String, dynamic>;
          expect(
            configData['curriculum_id'],
            'mishnayos',
            reason: 'StudyDayConfigCodec reads curriculum_id',
          );
          expect(
            configData['track_id'],
            7,
            reason: 'StudyDayConfigCodec reads track_id',
          );
          expect(
            configData['day_of_week'],
            1,
            reason: 'StudyDayConfigCodec reads day_of_week',
          );
          expect(
            configData['day_type'],
            'study',
            reason: 'StudyDayConfigCodec reads day_type',
          );
          expect(
            configData['updated_at'],
            now.toIso8601String(),
            reason: 'StudyDayConfigMerger uses updated_at as LWW timestamp',
          );

          // Doc-id.
          expect(
            args['configId'],
            'mishnayos_1_7',
            reason:
                'configId = {curriculum}_{dow}_{track} matches outbox doc-id convention',
          );
        },
      );
    },
  );

  // ── Goal parity ───────────────────────────────────────────────────────────────
  //
  // GoalMerger reads: curriculum_id, track_id, created_at, updated_at,
  //   description, target_percent, target_date, date_type, goal_type,
  //   pace_value, pace_unit.
  //
  // GoalEntity.toFirestore() outputs snake_case to match these field names.
  // R2-H1 fix: GoalEntity now has a trackId field; _toEntity passes goal.trackId
  //   through so toFirestore() emits track_id and GoalMerger no longer skips rows.

  group(
    'Goal parity — tutorUpsertGoal payload uses snake_case matching GoalMerger',
    () {
      test(
        'GoalEntity.toFirestore outputs snake_case for all merger-read fields',
        () {
          final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
          final goal = GoalEntity(
            curriculumId: CurriculumId.mishnayos,
            targetPercent: 100.0,
            targetDate: now,
            description: 'Finish by Pesach',
            dateType: 'gregorian',
            goalType: 'deadline',
            createdAt: now,
            updatedAt: now,
          );

          final data = goal.toFirestore();

          // All merger-required fields present in snake_case.
          expect(
            data.containsKey('curriculum_id'),
            isTrue,
            reason:
                'GoalMerger reads curriculum_id (was camelCase — fixed by S2)',
          );
          expect(
            data.containsKey('target_percent'),
            isTrue,
            reason: 'GoalMerger reads target_percent',
          );
          expect(
            data.containsKey('target_date'),
            isTrue,
            reason: 'GoalMerger reads target_date',
          );
          expect(
            data.containsKey('description'),
            isTrue,
            reason: 'GoalMerger reads description',
          );
          expect(
            data.containsKey('date_type'),
            isTrue,
            reason: 'GoalMerger reads date_type',
          );
          expect(
            data.containsKey('goal_type'),
            isTrue,
            reason: 'GoalMerger reads goal_type',
          );
          expect(
            data.containsKey('pace_value'),
            isTrue,
            reason: 'GoalMerger reads pace_value',
          );
          expect(
            data.containsKey('pace_unit'),
            isTrue,
            reason: 'GoalMerger reads pace_unit (was pacePeriod — fixed by S2)',
          );
          expect(
            data.containsKey('created_at'),
            isTrue,
            reason: 'GoalMerger reads created_at',
          );
          expect(
            data.containsKey('updated_at'),
            isTrue,
            reason: 'GoalMerger reads updated_at (LWW timestamp)',
          );

          // Values are correct.
          expect(data['curriculum_id'], CurriculumId.mishnayos.storageKey);
          expect(data['target_percent'], 100.0);
          expect(data['description'], 'Finish by Pesach');
          expect(data['goal_type'], 'deadline');
          expect(data['updated_at'], now.toIso8601String());

          // Verify no camelCase leakage.
          expect(
            data.containsKey('curriculumId'),
            isFalse,
            reason:
                'camelCase curriculumId must not be present after snake_case fix',
          );
          expect(data.containsKey('targetPercent'), isFalse);
          expect(data.containsKey('pacePeriod'), isFalse);
          expect(data.containsKey('createdAt'), isFalse);
          expect(data.containsKey('updatedAt'), isFalse);
        },
      );

      test('GoalEntity.fromFirestore round-trips through snake_case keys', () {
        final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
        final original = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 80.0,
          description: 'Round-trip test',
          dateType: 'hebrew',
          goalType: 'pace',
          paceValue: 2,
          pacePeriod: 'per_week',
          createdAt: now,
          updatedAt: now,
        );

        final data = original.toFirestore();
        final restored = GoalEntity.fromFirestore(data);

        expect(restored.curriculumId, original.curriculumId);
        expect(restored.targetPercent, original.targetPercent);
        expect(restored.description, original.description);
        expect(restored.dateType, original.dateType);
        expect(restored.goalType, original.goalType);
        expect(restored.paceValue, original.paceValue);
        expect(restored.pacePeriod, original.pacePeriod);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });

      // R2-H1 fix: GoalEntity now has trackId; toFirestore emits track_id when set.
      test(
        'GoalEntity.toFirestore includes track_id when trackId is set (H1 fix)',
        () {
          final now = DateTime.utc(2026, 5, 28);
          final goal = GoalEntity(
            curriculumId: CurriculumId.mishnayos,
            trackId: 7,
            createdAt: now,
            updatedAt: now,
          );

          final data = goal.toFirestore();
          expect(
            data.containsKey('track_id'),
            isTrue,
            reason:
                'GoalMerger reads track_id; omitting it caused silent data loss.',
          );
          expect(data['track_id'], 7);
        },
      );

      test('GoalEntity.toFirestore omits track_id when trackId is null', () {
        final now = DateTime.utc(2026, 5, 28);
        final goal = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          createdAt: now,
          updatedAt: now,
        );

        final data = goal.toFirestore();
        expect(
          data.containsKey('track_id'),
          isFalse,
          reason: 'track_id is omitted when not set (nullable field).',
        );
      });

      test(
        'router passes goal payload to CF with goalId from id key',
        () async {
          final record = _InvokerRecord();
          final router = _router(record);

          final now = DateTime.utc(2026, 5, 28, 10, 0, 0);
          final goal = GoalEntity(
            curriculumId: CurriculumId.mishnayos,
            targetPercent: 100.0,
            description: 'Test',
            goalType: 'deadline',
            targetDate: now,
            createdAt: now,
            updatedAt: now,
          );
          final payload = goal.toFirestore();
          payload['id'] = goal.firestoreId;

          await router.pushGoal(payload);

          expect(record.calls, hasLength(1));
          final call = record.calls.first;
          expect(call.fn, 'tutorUpsertGoal');
          final args = call.args;
          expect(args['goalId'], goal.firestoreId);
          final goalData = args['goalData'] as Map<String, dynamic>;
          expect(goalData['curriculum_id'], CurriculumId.mishnayos.storageKey);
          expect(goalData['updated_at'], now.toIso8601String());
        },
      );
    },
  );
} // end main
