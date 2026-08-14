// S1 — migration of the former TutoredWriteRouter tests.
//
// The archived sync engine removed TutoredWriteRouter and SyncWriteFacade.
// Current tutor-originated writes are Cloud-Functions-only through
// TutorWriteService; direct tutor writes to the parent's Firestore tree are
// forbidden by the current rules. Consequently, createFakeFirestore cannot
// exercise this current write path: the service's injectable callable seam is
// the equivalent used by s4_tutor_write_service_permission_test.dart.

@Tags(['s1', 'tutor_mode', 'routing', 'keystone'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';

class _FakeInvokerRecord {
  final List<({String fn, Map<String, dynamic> args})> calls = [];

  Future<void> call(String fn, Map<String, dynamic> args) async {
    calls.add((fn: fn, args: Map<String, dynamic>.from(args)));
  }

  ({String fn, Map<String, dynamic> args})? get lastCall =>
      calls.isEmpty ? null : calls.last;
}

const _grantId = 'grant_test_001';
const _ownerUid = 'parent_uid_abc';
const _profileId = '01JQ3K5M8N2P4R6T7V9X0Z1AB';

TutorWriteService _service(_FakeInvokerRecord record) =>
    TutorWriteService(invoker: record.call);

void main() {
  group('AC1 — current TutorWriteService callable payloads', () {
    test('pushGoal → tutorUpsertGoal with correct args', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).upsertGoal(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        goalId: 'goal_xyz',
        goalData: {'id': 'goal_xyz', 'targetPercent': 80.0},
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorUpsertGoal');
      expect(record.lastCall!.args['grantId'], _grantId);
      expect(record.lastCall!.args['ownerUid'], _ownerUid);
      expect(record.lastCall!.args['profileId'], _profileId);
      expect(record.lastCall!.args['goalId'], 'goal_xyz');
      expect(record.lastCall!.args['goalData'], containsPair('id', 'goal_xyz'));
    });

    test('deleteGoal → tutorDeleteGoal with the supplied goalId', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).deleteGoal(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        goalId: 'goal_to_delete',
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorDeleteGoal');
      expect(record.lastCall!.args['goalId'], 'goal_to_delete');
      expect(record.lastCall!.args['grantId'], _grantId);
      expect(record.lastCall!.args['ownerUid'], _ownerUid);
      expect(record.lastCall!.args['profileId'], _profileId);
    });

    test('pushCurriculumTrack → tutorUpsertTrack with trackId', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).upsertTrack(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        trackId: 'mishnayos',
        trackData: {'curriculum_id': 'mishnayos', 'state': 'active'},
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorUpsertTrack');
      expect(record.lastCall!.args['trackId'], 'mishnayos');
      expect(
        record.lastCall!.args['trackData'],
        containsPair('curriculum_id', 'mishnayos'),
      );
    });

    test(
      'pushStageDefinitions → one tutorUpsertStageDefinition per stage with '
      '{trackId}_{stageOrder} as stageId',
      () {
        markTestSkipped(
          'RETIRED: verified current TutorWriteService exposes only the '
          'single-stage upsertStageDefinition callable; the former router '
          'batch loop and its stage-ID generation no longer exist.',
        );
      },
    );

    test(
      'pushStudyDayConfig → tutorUpsertStudyDayConfig with composite configId',
      () async {
        final record = _FakeInvokerRecord();
        final result = await _service(record).upsertStudyDayConfig(
          grantId: _grantId,
          ownerUid: _ownerUid,
          profileId: _profileId,
          configId: 'daf_yomi_1_3',
          configData: {'curriculum_id': 'daf_yomi', 'day_of_week': 1},
        );

        expect(result, isA<TutorWriteSuccess>());
        expect(record.lastCall!.fn, 'tutorUpsertStudyDayConfig');
        expect(record.lastCall!.args['configId'], 'daf_yomi_1_3');
        expect(
          record.lastCall!.args['configData'],
          containsPair('curriculum_id', 'daf_yomi'),
        );
      },
    );
  });

  group('AUD-tutoring-07 — partial stage failure', () {
    test(
      'CF fails on 2nd of 3 stages → TutorWriteException carries the '
      'stage IDs that already committed before the failure',
      () {
        markTestSkipped(
          'RETIRED: verified the current service has no multi-stage router '
          'loop, succeededStageIds field, or TutorWriteException contract; '
          'each callable returns a TutorWriteResult independently.',
        );
      },
    );

    test(
      'all stages succeed → succeededStageIds is not consulted (no '
      'exception thrown)',
      () {
        markTestSkipped(
          'RETIRED: verified succeededStageIds belongs only to the deleted '
          'router batch-loop abstraction; it is absent from TutorWriteService.',
        );
      },
    );
  });

  group('AUD-tutoring-17 — invalid profile ID', () {
    test(
      'pushGoal with empty profileId → TutorWriteException '
      '(code: invalid-profile-id)',
      () {
        markTestSkipped(
          'RETIRED: verified the current TutorWriteService does not validate '
          'profile IDs or define invalid-profile-id/TutorWriteException; the '
          'former router validation was deleted.',
        );
      },
    );

    test(
      'deleteCompletion with empty profileId → TutorWriteException '
      '(code: invalid-profile-id)',
      () {
        markTestSkipped(
          'RETIRED: verified the current TutorWriteService does not validate '
          'profile IDs or define invalid-profile-id/TutorWriteException; the '
          'former router validation was deleted.',
        );
      },
    );
  });

  group('AC2 — non-tutored session pass-through', () {
    test('pushGoal → delegate called, CF not called', () {
      markTestSkipped(
        'RETIRED: verified TutoredWriteRouter, its session selection branch, '
        'and SyncWriteFacade delegate were deleted; TutorWriteService has no '
        'non-tutored/outbox mode.',
      );
    });

    test('deleteGoal → delegate called, CF not called', () {
      markTestSkipped(
        'RETIRED: verified TutoredWriteRouter, its session selection branch, '
        'and SyncWriteFacade delegate were deleted; TutorWriteService has no '
        'non-tutored/outbox mode.',
      );
    });

    test('pushCurriculumTrack → delegate called, CF not called', () {
      markTestSkipped(
        'RETIRED: verified TutoredWriteRouter, its session selection branch, '
        'and SyncWriteFacade delegate were deleted; TutorWriteService has no '
        'non-tutored/outbox mode.',
      );
    });

    test('pushStageDefinitions → delegate called, CF not called', () {
      markTestSkipped(
        'RETIRED: verified TutoredWriteRouter, its session selection branch, '
        'and SyncWriteFacade delegate were deleted; TutorWriteService has no '
        'non-tutored/outbox mode.',
      );
    });

    test('pushStudyDayConfig → delegate called, CF not called', () {
      markTestSkipped(
        'RETIRED: verified TutoredWriteRouter, its session selection branch, '
        'and SyncWriteFacade delegate were deleted; TutorWriteService has no '
        'non-tutored/outbox mode.',
      );
    });
  });

  group('AC3 — outbox isolation', () {
    test('all intercepted entity kinds: delegate totalEnqueueCount stays 0', () {
      markTestSkipped(
        'RETIRED: verified SyncWriteFacade/outbox and all router interception '
        'chokepoints were deleted; current tutor writes have no delegate to '
        'inspect.',
      );
    });

    test('non-intercepted pass-throughs still reach delegate', () {
      markTestSkipped(
        'RETIRED: verified the deleted router was the only abstraction that '
        'classified pass-through entities; no current delegate/outbox API exists.',
      );
    });
  });

  group('AC4 — current TutorWriteService error results', () {
    test('pushGoal CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('network timeout'),
      );

      final result = await service.upsertGoal(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        goalId: 'g1',
        goalData: {'id': 'g1'},
      );

      expect(result, isA<TutorWriteFailure>());
      expect((result as TutorWriteFailure).code, 'unknown-error');
    });

    test('deleteGoal CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('network timeout'),
      );

      final result = await service.deleteGoal(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        goalId: 'g1',
      );

      expect(result, isA<TutorWriteFailure>());
      expect((result as TutorWriteFailure).code, 'unknown-error');
    });
  });

  group('F2 — profile program', () {
    test('tutored: pushProfileProgram → tutorSetProfileProgram', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).setProfileProgram(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        programId: 'daf_yomi',
        programData: {
          'curriculum_id': 'daf_yomi',
          'program_id': 'prog_001',
        },
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorSetProfileProgram');
      expect(record.lastCall!.args['programId'], 'daf_yomi');
      expect(
        record.lastCall!.args['programData'],
        containsPair('curriculum_id', 'daf_yomi'),
      );
    });

    test('non-tutored: pushProfileProgram passes through to delegate', () {
      markTestSkipped(
        'RETIRED: verified the deleted router/facade were the only current '
        'pass-through implementation; TutorWriteService has no non-tutored mode.',
      );
    });

    test('tutored: pushProfileProgram CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('network timeout'),
      );

      final result = await service.setProfileProgram(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        programId: 'daf_yomi',
        programData: {'program_id': 'prog_001'},
      );

      expect(result, isA<TutorWriteFailure>());
    });

    test('AC3 extended: pushProfileProgram in tutored mode: 0 outbox depth', () {
      markTestSkipped(
        'RETIRED: verified the deleted SyncWriteFacade outbox was the only '
        'depth being measured; TutorWriteService has no outbox integration.',
      );
    });
  });

  group('S4-A — gamification settings', () {
    test(
      'tutored + builder: calls tutorUpdateGamificationSettings twice '
      '(once per permKey)',
      () {
        markTestSkipped(
          'RETIRED: verified the snapshot builder and two-call routing policy '
          'belonged to the deleted router; current TutorWriteService accepts '
          'one already-shaped settingsData call at a time.',
        );
      },
    );

    test(
      'tutored without builder: falls back to delegate (gamification passes through)',
      () {
        markTestSkipped(
          'RETIRED: verified gamificationSnapshotBuilder and delegate fallback '
          'were deleted with TutoredWriteRouter; no current outbox path exists.',
        );
      },
    );

    test('non-tutored: always delegates to outbox', () {
      markTestSkipped(
        'RETIRED: verified TutorWriteService has no non-tutored mode and the '
        'SyncWriteFacade outbox was deleted.',
      );
    });

    test('CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('CF timeout'),
      );

      final result = await service.updateGamificationSettings(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        permKey: 'can_edit_rewards',
        settingsData: {'reward_settings': <Map<String, dynamic>>[]},
      );

      expect(result, isA<TutorWriteFailure>());
    });
  });

  group('S4-B — learner profile edit', () {
    test('tutored: display_name field extracted and forwarded', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).editProfile(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        displayName: 'Yankel',
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorEditProfile');
      expect(record.lastCall!.args['displayName'], 'Yankel');
    });

    test('tutored: camelCase displayName key extracted', () {
      markTestSkipped(
        'RETIRED: verified raw profile-map key extraction was router logic; '
        'current TutorWriteService.editProfile receives typed displayName directly.',
      );
    });

    test('tutored: avatar_index (int) converted to string', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).editProfile(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        avatar: '5',
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.args['avatar'], '5');
    });

    test(
      'tutored: profile with no editable fields → no CF call, no delegate',
      () {
        markTestSkipped(
          'RETIRED: verified editable-field filtering and the no-delegate '
          'outbox assertion were router behavior; current editProfile requires '
          'a typed editable argument and has no delegate.',
        );
      },
    );

    test('non-tutored: passes through to delegate', () {
      markTestSkipped(
        'RETIRED: verified the deleted router/facade were the only current '
        'pass-through implementation; TutorWriteService has no non-tutored mode.',
      );
    });

    test('CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('CF timeout'),
      );

      final result = await service.editProfile(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        displayName: 'Test',
      );

      expect(result, isA<TutorWriteFailure>());
    });
  });

  group('S4-C — completion reset', () {
    test('tutored: completion id forwarded to CF', () async {
      final record = _FakeInvokerRecord();
      final result = await _service(record).resetCompletion(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        completionId: 'completion_xyz_123',
      );

      expect(result, isA<TutorWriteSuccess>());
      expect(record.lastCall!.fn, 'tutorResetCompletion');
      expect(record.lastCall!.args['completionId'], 'completion_xyz_123');
      expect(record.lastCall!.args['grantId'], _grantId);
    });

    test('non-tutored: passes through to delegate (no-op in outbox)', () {
      markTestSkipped(
        'RETIRED: verified the deleted router/facade were the only current '
        'pass-through implementation; TutorWriteService has no non-tutored mode.',
      );
    });

    test('CF failure → TutorWriteFailure', () async {
      final service = TutorWriteService(
        invoker: (_, __) async => throw Exception('CF timeout'),
      );

      final result = await service.resetCompletion(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        completionId: 'comp_fail',
      );

      expect(result, isA<TutorWriteFailure>());
    });

    test('AC3 extended: deleteCompletion in tutored mode: 0 outbox depth', () {
      markTestSkipped(
        'RETIRED: verified the deleted SyncWriteFacade outbox was the only '
        'depth being measured; TutorWriteService has no outbox integration.',
      );
    });
  });

  group('AUD-t-tutoring-02 — always-pass-through methods', () {
    test('tutored: pushSettings always reaches delegate, CF never invoked', () {
      markTestSkipped(
        'RETIRED: verified pushSettings pass-through depended on deleted '
        'SyncWriteFacade/TutoredWriteRouter APIs; no current equivalent exists.',
      );
    });

    test(
      'tutored: pushLearningOrder always reaches delegate, CF never invoked',
      () {
        markTestSkipped(
          'RETIRED: verified pushLearningOrder pass-through depended on deleted '
          'SyncWriteFacade/TutoredWriteRouter APIs; no current equivalent exists.',
        );
      },
    );

    test(
      'tutored: pushUiPreferencesSnapshot always reaches delegate, CF never invoked',
      () {
        markTestSkipped(
          'RETIRED: verified pushUiPreferencesSnapshot pass-through depended '
          'on deleted SyncWriteFacade/TutoredWriteRouter APIs; no current '
          'equivalent exists.',
        );
      },
    );

    test(
      'tutored: deleteLearnerProfile always reaches delegate, CF never invoked '
      '(talmid profile deletion is not a tutor right)',
      () {
        markTestSkipped(
          'RETIRED: verified deleteLearnerProfile pass-through depended on '
          'deleted SyncWriteFacade/TutoredWriteRouter APIs; no current '
          'equivalent exists.',
        );
      },
    );
  });
}
