// S1 — TutoredWriteRouter unit tests
//
// AC1: Tutored session → router invokes the correct CF name + payload with
//      grantId/ownerUid/profileId; delegate (outbox) NOT called.
// AC2: Non-tutored session → outbox (delegate) called unchanged; CF NOT invoked.
// AC3: Outbox isolation — a tutored write at either chokepoint never reaches
//      the delegate outbox path.
// AC4: CF failure → TutorWriteException thrown (never silently strand).

@Tags(['s1', 'tutor_mode', 'routing', 'keystone'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/tutoring/data/routers/tutored_write_router.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

// ── Fake TutorWriteService (via injectable TutorCallableInvoker) ───────────

/// Records every call made to the fake CF invoker.
class _FakeInvokerRecord {
  final List<({String fn, Map<String, dynamic> args})> calls = [];

  Future<void> call(String fn, Map<String, dynamic> args) async {
    calls.add((fn: fn, args: Map<String, dynamic>.from(args)));
  }

  /// Simulates a CF failure.
  Future<void> failingCall(String fn, Map<String, dynamic> args) async {
    throw Exception('CF network error');
  }

  bool get wasCalled => calls.isNotEmpty;
  int get callCount => calls.length;

  ({String fn, Map<String, dynamic> args})? get lastCall =>
      calls.isEmpty ? null : calls.last;
}

// ── Fake SyncWriteFacade (delegate / outbox path) ─────────────────────────

class _FakeDelegate implements SyncWriteFacade {
  int pushGoalCount = 0;
  int deleteGoalCount = 0;
  int pushTrackCount = 0;
  int pushStageDefinitionsCount = 0;
  int pushStudyDayConfigCount = 0;
  int pushGamificationCount = 0;
  int pushBookmarkCount = 0;
  int pushProfileProgramCount = 0;
  int pushLearnerProfileCount = 0;
  int deleteCompletionCount = 0;

  // Aggregate for "outbox depth"
  int get totalEnqueueCount =>
      pushGoalCount +
      deleteGoalCount +
      pushTrackCount +
      pushStageDefinitionsCount +
      pushStudyDayConfigCount +
      pushGamificationCount +
      pushBookmarkCount +
      pushProfileProgramCount +
      pushLearnerProfileCount +
      deleteCompletionCount;

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async => pushGoalCount++;

  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async =>
      deleteGoalCount++;

  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async =>
      pushTrackCount++;

  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async => pushStageDefinitionsCount++;

  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async =>
      pushStudyDayConfigCount++;

  @override
  Future<void> pushGamificationSettingsSnapshot() async =>
      pushGamificationCount++;

  @override
  Future<void> pushUiPreferencesSnapshot() async {}

  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async =>
      pushBookmarkCount++;

  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async =>
      pushProfileProgramCount++;

  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async =>
      pushLearnerProfileCount++;

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}

  @override
  Future<void> deleteCompletion(String completionId) async =>
      deleteCompletionCount++;
}

// ── Constants ─────────────────────────────────────────────────────────────

const _grantId = 'grant_test_001';
const _ownerUid = 'parent_uid_abc';
const _profileId = '42';

const _fullPerms = TutorPermissions(
  canViewProgress: true,
  canViewContent: true,
  canBulkPriorCompletion: true,
  canResetCompletion: true,
  canEditGoals: true,
  canEditStages: true,
  canEditRewards: true,
  canEditStudyDays: true,
  canEditPoints: true,
);

const _tutoredSelection = TutoredProfileSelection(
  profileId: _profileId,
  ownerUid: _ownerUid,
  grantId: _grantId,
  permissions: _fullPerms,
);

// ── Helpers ────────────────────────────────────────────────────────────────

/// Builds a router in tutored mode using [record] as the CF invoker.
TutoredWriteRouter _tutored(
  _FakeInvokerRecord record,
  _FakeDelegate delegate,
) => TutoredWriteRouter(
  delegate: delegate,
  writeService: TutorWriteService(invoker: record.call),
  selection: _tutoredSelection,
);

/// Builds a router in non-tutored (pass-through) mode.
TutoredWriteRouter _nonTutored(
  _FakeInvokerRecord record,
  _FakeDelegate delegate,
) => TutoredWriteRouter(
  delegate: delegate,
  writeService: TutorWriteService(invoker: record.call),
  selection: null,
);

/// Builds a tutored router with an optional gamification snapshot builder.
TutoredWriteRouter _tutoredWithGamification(
  _FakeInvokerRecord record,
  _FakeDelegate delegate, {
  Map<String, dynamic>? snapshot,
}) => TutoredWriteRouter(
  delegate: delegate,
  writeService: TutorWriteService(invoker: record.call),
  selection: _tutoredSelection,
  gamificationSnapshotBuilder: () async =>
      snapshot ??
      <String, dynamic>{
        'reward_settings': <Map<String, dynamic>>[],
        'points_config': <Map<String, dynamic>>[],
      },
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // AC1: tutored session → correct CF invoked, delegate NOT called
  // ────────────────────────────────────────────────────────────────────────────

  group('AC1 — tutored session routes to CF, not outbox', () {
    test('pushGoal → tutorUpsertGoal with correct args', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      await router.pushGoal({
        'id': 'goal_xyz',
        'curriculumId': 'daf_yomi',
        'targetPercent': 80.0,
      });

      expect(record.callCount, 1);
      expect(record.lastCall!.fn, 'tutorUpsertGoal');
      expect(record.lastCall!.args['grantId'], _grantId);
      expect(record.lastCall!.args['ownerUid'], _ownerUid);
      expect(record.lastCall!.args['profileId'], 42);
      expect(record.lastCall!.args['goalId'], 'goal_xyz');
      expect(record.lastCall!.args['goalData'], containsPair('id', 'goal_xyz'));

      // Outbox depth 0 — delegate was NOT called
      expect(delegate.pushGoalCount, 0);
      expect(delegate.totalEnqueueCount, 0);
    });

    test(
      'deleteGoal → tutorDeleteGoal with correct goalId from firestore_id',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.deleteGoal({
          'firestore_id': 'goal_to_delete',
          'curriculum_id': 'daf_yomi',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorDeleteGoal');
        expect(record.lastCall!.args['grantId'], _grantId);
        expect(record.lastCall!.args['ownerUid'], _ownerUid);
        expect(record.lastCall!.args['profileId'], 42);
        expect(record.lastCall!.args['goalId'], 'goal_to_delete');

        expect(delegate.deleteGoalCount, 0);
        expect(delegate.totalEnqueueCount, 0);
      },
    );

    test(
      'pushCurriculumTrack → tutorUpsertTrack with curriculumId as trackId',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushCurriculumTrack({
          'curriculum_id': 'mishnayos',
          'state': 'active',
          'activated_at': '2026-01-01T00:00:00.000Z',
          'state_changed_at': '2026-01-01T00:00:00.000Z',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorUpsertTrack');
        expect(record.lastCall!.args['grantId'], _grantId);
        expect(record.lastCall!.args['ownerUid'], _ownerUid);
        expect(record.lastCall!.args['profileId'], 42);
        expect(record.lastCall!.args['trackId'], 'mishnayos');
        expect(
          record.lastCall!.args['trackData'],
          containsPair('curriculum_id', 'mishnayos'),
        );

        expect(delegate.pushTrackCount, 0);
        expect(delegate.totalEnqueueCount, 0);
      },
    );

    test('pushStageDefinitions → one tutorUpsertStageDefinition per stage with '
        '{trackId}_{stageOrder} as stageId', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      final updatedAt = DateTime.utc(2026, 1, 1);
      await router.pushStageDefinitions(
        trackId: 7,
        curriculumId: 'mishnayos',
        stages: [
          {'stage_order': 1, 'stage_name': 'Learn', 'is_default': true},
          {'stage_order': 2, 'stage_name': 'Review', 'is_default': false},
        ],
        updatedAt: updatedAt,
      );

      // One CF call per stage
      expect(record.callCount, 2);
      expect(record.calls[0].fn, 'tutorUpsertStageDefinition');
      expect(record.calls[0].args['stageId'], '7_1');
      final stageData0 =
          record.calls[0].args['stageData'] as Map<String, dynamic>;
      expect(stageData0['track_id'], 7);
      expect(stageData0['curriculum_id'], 'mishnayos');
      expect(record.calls[1].args['stageId'], '7_2');

      // Both CF calls carry the correct session context
      for (final call in record.calls) {
        expect(call.args['grantId'], _grantId);
        expect(call.args['ownerUid'], _ownerUid);
        expect(call.args['profileId'], 42);
      }

      expect(delegate.pushStageDefinitionsCount, 0);
      expect(delegate.totalEnqueueCount, 0);
    });

    test(
      'pushStudyDayConfig → tutorUpsertStudyDayConfig with composite configId',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushStudyDayConfig({
          'curriculum_id': 'daf_yomi',
          'day_of_week': 1,
          'track_id': 3,
          'day_type': 'regular',
          'updated_at': '2026-01-01T00:00:00.000Z',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorUpsertStudyDayConfig');
        expect(record.lastCall!.args['grantId'], _grantId);
        expect(record.lastCall!.args['ownerUid'], _ownerUid);
        expect(record.lastCall!.args['profileId'], 42);
        expect(record.lastCall!.args['configId'], 'daf_yomi_1_3');
        expect(
          record.lastCall!.args['configData'],
          containsPair('curriculum_id', 'daf_yomi'),
        );

        expect(delegate.pushStudyDayConfigCount, 0);
        expect(delegate.totalEnqueueCount, 0);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // AC2: non-tutored session → delegate called, CF NOT invoked
  // ────────────────────────────────────────────────────────────────────────────

  group('AC2 — non-tutored session passes through to outbox (regression)', () {
    test('pushGoal → delegate called, CF not called', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushGoal({'id': 'goal_123', 'curriculumId': 'daf_yomi'});

      expect(delegate.pushGoalCount, 1, reason: 'delegate must be called');
      expect(record.wasCalled, isFalse, reason: 'CF must NOT be invoked');
    });

    test('deleteGoal → delegate called, CF not called', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.deleteGoal({'firestore_id': 'goal_123'});

      expect(delegate.deleteGoalCount, 1);
      expect(record.wasCalled, isFalse);
    });

    test('pushCurriculumTrack → delegate called, CF not called', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushCurriculumTrack({'curriculum_id': 'mishnayos'});

      expect(delegate.pushTrackCount, 1);
      expect(record.wasCalled, isFalse);
    });

    test('pushStageDefinitions → delegate called, CF not called', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushStageDefinitions(
        trackId: 1,
        curriculumId: 'mishnayos',
        stages: [
          {'stage_order': 1},
        ],
        updatedAt: DateTime.utc(2026),
      );

      expect(delegate.pushStageDefinitionsCount, 1);
      expect(record.wasCalled, isFalse);
    });

    test('pushStudyDayConfig → delegate called, CF not called', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushStudyDayConfig({
        'curriculum_id': 'daf_yomi',
        'day_of_week': 1,
        'track_id': 3,
      });

      expect(delegate.pushStudyDayConfigCount, 1);
      expect(record.wasCalled, isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // AC3: Outbox isolation — tutored writes never reach the delegate outbox
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'AC3 — outbox isolation hardening (tutored writes never reach outbox)',
    () {
      test(
        'all intercepted entity kinds: delegate totalEnqueueCount stays 0',
        () async {
          final record = _FakeInvokerRecord();
          final delegate = _FakeDelegate();
          final router = _tutored(record, delegate);

          await router.pushGoal({'id': 'g1'});
          await router.deleteGoal({'firestore_id': 'g2'});
          await router.pushCurriculumTrack({'curriculum_id': 'daf_yomi'});
          await router.pushStageDefinitions(
            trackId: 1,
            curriculumId: 'daf_yomi',
            stages: [
              {'stage_order': 1},
            ],
            updatedAt: DateTime.utc(2026),
          );
          await router.pushStudyDayConfig({
            'curriculum_id': 'daf_yomi',
            'day_of_week': 1,
            'track_id': 1,
          });
          await router.pushBookmark({
            'curriculum_id': 'daf_yomi',
            'track_type': 'standard',
            'content_item_id': 'Berakhot.2a',
          });
          await router.pushProfileProgram({
            'curriculum_id': 'daf_yomi',
            'program_id': 'prog_001',
            'profile_id': 42,
          });

          expect(
            delegate.totalEnqueueCount,
            0,
            reason: 'No tutored write must reach the outbox delegate',
          );
          expect(
            record.callCount,
            7,
            reason: '7 CF calls made (one per write)',
          );
        },
      );

      test('non-intercepted pass-throughs still reach delegate', () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        // pushGamificationSettingsSnapshot passes through to delegate (S4 scope)
        await router.pushGamificationSettingsSnapshot();

        expect(delegate.pushGamificationCount, 1);
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC4: CF failure → TutorWriteException (never silently strand)
  // ────────────────────────────────────────────────────────────────────────────

  group('AC4 — CF failure propagates as TutorWriteException', () {
    test('pushGoal CF failure → throws TutorWriteException', () async {
      final delegate = _FakeDelegate();
      final router = TutoredWriteRouter(
        delegate: delegate,
        writeService: TutorWriteService(
          invoker: (_, __) async => throw Exception('network timeout'),
        ),
        selection: _tutoredSelection,
      );

      await expectLater(
        () => router.pushGoal({'id': 'g1'}),
        throwsA(isA<TutorWriteException>()),
      );

      // Delegate must NOT have been called (the exception happened in the CF path)
      expect(delegate.pushGoalCount, 0);
    });

    test('deleteGoal CF failure → throws TutorWriteException', () async {
      final delegate = _FakeDelegate();
      final router = TutoredWriteRouter(
        delegate: delegate,
        writeService: TutorWriteService(
          invoker: (_, __) async => throw Exception('network timeout'),
        ),
        selection: _tutoredSelection,
      );

      await expectLater(
        () => router.deleteGoal({'firestore_id': 'g1'}),
        throwsA(isA<TutorWriteException>()),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // S3: pushBookmark routing (new in S3 — parity CFs)
  // ────────────────────────────────────────────────────────────────────────────

  group('S3 — pushBookmark routes to tutorUpsertBookmark', () {
    test(
      'tutored: pushBookmark → tutorUpsertBookmark with {curr}_{trackType} id',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushBookmark({
          'curriculum_id': 'daf_yomi',
          'track_type': 'standard',
          'content_item_id': 'Berakhot.2a',
          'updated_at': '2026-01-01T00:00:00.000Z',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorUpsertBookmark');
        expect(record.lastCall!.args['grantId'], _grantId);
        expect(record.lastCall!.args['ownerUid'], _ownerUid);
        expect(record.lastCall!.args['profileId'], 42);
        expect(record.lastCall!.args['bookmarkId'], 'daf_yomi_standard');
        expect(
          record.lastCall!.args['bookmarkData'],
          containsPair('curriculum_id', 'daf_yomi'),
        );

        expect(delegate.pushBookmarkCount, 0);
        expect(delegate.totalEnqueueCount, 0);
      },
    );

    test(
      'tutored: pushBookmark without track_type falls back to curriculum_id',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushBookmark({
          'curriculum_id': 'mishnayos',
          'content_item_id': 'Berakhot.1.1',
          'updated_at': '2026-01-01T00:00:00.000Z',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorUpsertBookmark');
        // M2 fix: fallback uses {curriculumId}_ (trailing underscore) to match
        // parent-side gateway which always appends _{trackType}.
        expect(record.lastCall!.args['bookmarkId'], 'mishnayos_');
        expect(delegate.pushBookmarkCount, 0);
      },
    );

    test('non-tutored: pushBookmark passes through to delegate', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushBookmark({
        'curriculum_id': 'daf_yomi',
        'track_type': 'standard',
        'content_item_id': 'Berakhot.2a',
      });

      expect(delegate.pushBookmarkCount, 1);
      expect(record.wasCalled, isFalse);
    });

    test(
      'tutored: pushBookmark CF failure → throws TutorWriteException',
      () async {
        final delegate = _FakeDelegate();
        final router = TutoredWriteRouter(
          delegate: delegate,
          writeService: TutorWriteService(
            invoker: (_, __) async => throw Exception('network timeout'),
          ),
          selection: _tutoredSelection,
        );

        await expectLater(
          () => router.pushBookmark({
            'curriculum_id': 'daf_yomi',
            'track_type': 'standard',
            'content_item_id': 'Berakhot.2a',
          }),
          throwsA(isA<TutorWriteException>()),
        );

        expect(delegate.pushBookmarkCount, 0);
      },
    );

    test(
      'AC3 extended: pushBookmark in tutored mode contributes 0 to outbox',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushBookmark({
          'curriculum_id': 'daf_yomi',
          'track_type': 'standard',
          'content_item_id': 'Berakhot.2a',
        });

        expect(delegate.totalEnqueueCount, 0);
        expect(record.callCount, 1);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // F2: pushProfileProgram → tutorSetProfileProgram
  // ────────────────────────────────────────────────────────────────────────────

  group('F2 — pushProfileProgram routes to tutorSetProfileProgram', () {
    test(
      'tutored: pushProfileProgram → tutorSetProfileProgram with correct args',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushProfileProgram({
          'profile_id': 42,
          'curriculum_id': 'daf_yomi',
          'program_id': 'prog_001',
          'tracking_start_date': '2026-01-01T00:00:00.000Z',
          'tracking_start_ref': 'Berakhot.2a',
        });

        expect(record.callCount, 1);
        expect(record.lastCall!.fn, 'tutorSetProfileProgram');
        expect(record.lastCall!.args['grantId'], _grantId);
        expect(record.lastCall!.args['ownerUid'], _ownerUid);
        expect(record.lastCall!.args['profileId'], 42);
        // C1 fix: doc-id is curriculum_id (matches parent-side gateway).
        expect(record.lastCall!.args['programId'], 'daf_yomi');
        expect(
          record.lastCall!.args['programData'],
          containsPair('curriculum_id', 'daf_yomi'),
        );

        expect(delegate.pushProfileProgramCount, 0);
        expect(delegate.totalEnqueueCount, 0);
      },
    );

    test('non-tutored: pushProfileProgram passes through to delegate', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushProfileProgram({
        'curriculum_id': 'daf_yomi',
        'program_id': 'prog_001',
        'profile_id': 42,
      });

      expect(delegate.pushProfileProgramCount, 1);
      expect(record.wasCalled, isFalse);
    });

    test(
      'tutored: pushProfileProgram CF failure → throws TutorWriteException',
      () async {
        final delegate = _FakeDelegate();
        final router = TutoredWriteRouter(
          delegate: delegate,
          writeService: TutorWriteService(
            invoker: (_, __) async => throw Exception('network timeout'),
          ),
          selection: _tutoredSelection,
        );

        await expectLater(
          () => router.pushProfileProgram({
            'curriculum_id': 'daf_yomi',
            'program_id': 'prog_001',
            'profile_id': 42,
          }),
          throwsA(isA<TutorWriteException>()),
        );

        expect(delegate.pushProfileProgramCount, 0);
      },
    );

    test(
      'AC3 extended: pushProfileProgram in tutored mode: 0 outbox depth',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushProfileProgram({
          'curriculum_id': 'daf_yomi',
          'program_id': 'prog_outbox_test',
          'profile_id': 42,
        });

        expect(delegate.totalEnqueueCount, 0);
        expect(record.callCount, 1);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // S4-A: pushGamificationSettingsSnapshot → tutorUpdateGamificationSettings
  // ────────────────────────────────────────────────────────────────────────────

  group('S4-A — pushGamificationSettingsSnapshot routes to CF with builder', () {
    test(
      'tutored + builder: calls tutorUpdateGamificationSettings twice (once per permKey)',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final snapshot = <String, dynamic>{
          'reward_settings': <Map<String, dynamic>>[],
          'points_config': <Map<String, dynamic>>[],
        };
        final router = _tutoredWithGamification(
          record,
          delegate,
          snapshot: snapshot,
        );

        await router.pushGamificationSettingsSnapshot();

        // R3-H2 fix: two CF calls — one per permission key.
        expect(record.callCount, 2);
        expect(record.calls[0].fn, 'tutorUpdateGamificationSettings');
        expect(record.calls[1].fn, 'tutorUpdateGamificationSettings');

        final rewardsCall = record.calls.firstWhere(
          (c) => c.args['permKey'] == 'can_edit_rewards',
        );
        final pointsCall = record.calls.firstWhere(
          (c) => c.args['permKey'] == 'can_edit_points',
        );

        expect(rewardsCall.args['grantId'], _grantId);
        expect(rewardsCall.args['ownerUid'], _ownerUid);
        expect(rewardsCall.args['profileId'], int.parse(_profileId));
        expect(
          (rewardsCall.args['settingsData'] as Map<String, dynamic>)['reward_settings'],
          isA<List<dynamic>>(),
        );
        expect(
          (pointsCall.args['settingsData'] as Map<String, dynamic>)['points_config'],
          isA<List<dynamic>>(),
        );
        expect(delegate.pushGamificationCount, 0);
      },
    );

    test(
      'tutored without builder: falls back to delegate (gamification passes through)',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = TutoredWriteRouter(
          delegate: delegate,
          writeService: TutorWriteService(invoker: record.call),
          selection: _tutoredSelection,
        );

        await router.pushGamificationSettingsSnapshot();

        expect(record.callCount, 0);
        expect(delegate.pushGamificationCount, 1);
      },
    );

    test('non-tutored: always delegates to outbox', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushGamificationSettingsSnapshot();

      expect(record.callCount, 0);
      expect(delegate.pushGamificationCount, 1);
    });

    test('CF failure → TutorWriteException', () async {
      final delegate = _FakeDelegate();
      final router = TutoredWriteRouter(
        delegate: delegate,
        writeService: TutorWriteService(
          invoker: (_, __) async => throw Exception('CF timeout'),
        ),
        selection: _tutoredSelection,
        gamificationSnapshotBuilder: () async => <String, dynamic>{
          'reward_settings': <Map<String, dynamic>>[],
        },
      );

      await expectLater(
        () => router.pushGamificationSettingsSnapshot(),
        throwsA(isA<TutorWriteException>()),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // S4-B: pushLearnerProfile → tutorEditProfile
  // ────────────────────────────────────────────────────────────────────────────

  group('S4-B — pushLearnerProfile routes to tutorEditProfile', () {
    test('tutored: display_name field extracted and forwarded', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      await router.pushLearnerProfile({
        'display_name': 'Yankel',
        'avatar_index': 3,
      });

      expect(record.callCount, 1);
      expect(record.lastCall!.fn, 'tutorEditProfile');
      final args = record.lastCall!.args;
      expect(args['displayName'], 'Yankel');
      expect(args['avatar'], '3');
      expect(delegate.pushLearnerProfileCount, 0);
    });

    test('tutored: camelCase displayName key extracted', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      await router.pushLearnerProfile({'displayName': 'Shmuel'});

      expect(record.callCount, 1);
      final args = record.lastCall!.args;
      expect(args['displayName'], 'Shmuel');
    });

    test('tutored: avatar_index (int) converted to string', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      await router.pushLearnerProfile({'avatar_index': 5});

      expect(record.callCount, 1);
      final args = record.lastCall!.args;
      expect(args['avatar'], '5');
    });

    test(
      'tutored: profile with no editable fields → no CF call, no delegate',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.pushLearnerProfile({
          'profile_id': 99,
          'account_id': 'acc_123',
          'created_at': '2024-01-01',
        });

        expect(record.callCount, 0);
        expect(delegate.pushLearnerProfileCount, 0);
      },
    );

    test('non-tutored: passes through to delegate', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.pushLearnerProfile({'display_name': 'Rivka'});

      expect(record.callCount, 0);
      expect(delegate.pushLearnerProfileCount, 1);
    });

    test('CF failure → TutorWriteException', () async {
      final delegate = _FakeDelegate();
      final router = TutoredWriteRouter(
        delegate: delegate,
        writeService: TutorWriteService(
          invoker: (_, __) async => throw Exception('CF timeout'),
        ),
        selection: _tutoredSelection,
      );

      await expectLater(
        () => router.pushLearnerProfile({'display_name': 'Test'}),
        throwsA(isA<TutorWriteException>()),
      );
      expect(delegate.pushLearnerProfileCount, 0);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // S4-C: deleteCompletion → tutorResetCompletion
  // ────────────────────────────────────────────────────────────────────────────

  group('S4-C — deleteCompletion routes to tutorResetCompletion', () {
    test('tutored: completion id forwarded to CF', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _tutored(record, delegate);

      await router.deleteCompletion('completion_xyz_123');

      expect(record.callCount, 1);
      expect(record.lastCall!.fn, 'tutorResetCompletion');
      final args = record.lastCall!.args;
      expect(args['completionId'], 'completion_xyz_123');
      expect(args['grantId'], _grantId);
      expect(args['ownerUid'], _ownerUid);
      expect(args['profileId'], int.parse(_profileId));
      expect(delegate.deleteCompletionCount, 0);
    });

    test('non-tutored: passes through to delegate (no-op in outbox)', () async {
      final record = _FakeInvokerRecord();
      final delegate = _FakeDelegate();
      final router = _nonTutored(record, delegate);

      await router.deleteCompletion('comp_abc');

      expect(record.callCount, 0);
      expect(delegate.deleteCompletionCount, 1);
    });

    test('CF failure → TutorWriteException', () async {
      final delegate = _FakeDelegate();
      final router = TutoredWriteRouter(
        delegate: delegate,
        writeService: TutorWriteService(
          invoker: (_, __) async => throw Exception('CF timeout'),
        ),
        selection: _tutoredSelection,
      );

      await expectLater(
        () => router.deleteCompletion('comp_fail'),
        throwsA(isA<TutorWriteException>()),
      );
      expect(delegate.deleteCompletionCount, 0);
    });

    test(
      'AC3 extended: deleteCompletion in tutored mode: 0 outbox depth',
      () async {
        final record = _FakeInvokerRecord();
        final delegate = _FakeDelegate();
        final router = _tutored(record, delegate);

        await router.deleteCompletion('comp_outbox_test');

        expect(delegate.totalEnqueueCount, 0);
        expect(record.callCount, 1);
      },
    );
  });
}
