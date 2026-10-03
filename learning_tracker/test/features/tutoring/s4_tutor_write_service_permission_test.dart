// S4 — TutorWriteService permission gating tests
//
// Verifies that:
//   AC1 — TutorWriteService maps FirebaseFunctionsException(permission-denied)
//          → TutorWriteFailure(code: 'permission-denied'). This is the exact
//          error a CF throws when the grant's flag is false (e.g.
//          can_reset_completion=false → tutorResetCompletion rejects).
//   AC2 — TutorWriteFailure is returned (not thrown) so the caller can inspect
//          the code and surface an appropriate UI error.
//   AC3 — A successful call returns TutorWriteSuccess (baseline correctness).
//   AC4 — Generic errors (non-Firebase) are also surfaced as TutorWriteFailure.
//
// The CF permission check is server-side (Admin SDK); these tests verify the
// CLIENT-SIDE contract: TutorWriteService maps the server's permission-denied
// response to a typed failure, ensuring restricted grants propagate cleanly.

@Tags(['s4', 'tutor_mode', 'permission_gating'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/utils/tutor_write_failure_message.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

// ── Fake invokers ──────────────────────────────────────────────────────────

/// Simulates a successful CF call.
Future<void> _successInvoker(String _, Map<String, dynamic> __) async {}

/// Simulates a successful Story 1.10 governed callable: the
/// `writeWithChangeLog` receipt (one change_log entry, server `at`).
Future<Object?> _governedSuccessInvoker(
  String _,
  Map<String, dynamic> args,
) async => {
  'success': true,
  'action_id': args['actionId'] ?? '01JT7T0SV0AAAAAAAAAAAAAAAA',
  'change_ids': const ['01JT7T0SV0AAAAAAAAAAAAAAAA'],
  'at': '2026-10-02T15:20:00.000Z',
  'replayed': false,
  'noop': false,
};

/// Simulates a successful Story 1.23 learning callable: the
/// `writeWithChangeLog` answer echoing the request's client ids.
Future<Object?> _learningSuccessInvoker(
  String _,
  Map<String, dynamic> args,
) async {
  final ids = <String>[
    if (args['events'] case final List<Object?> events)
      for (final e in events) (e! as Map)['id']! as String,
    if (args['eventId'] case final String id) id,
    if (args['replacement'] case final Map<Object?, Object?> r)
      r['id']! as String,
  ];
  return {
    'success': true,
    'action_id': args['actionId'],
    'event_ids': ids,
    'recorded_at': ids.isEmpty ? null : '2026-10-02T15:20:00.000Z',
    'replayed': false,
    'noop': ids.isEmpty,
  };
}

/// Simulates the CF rejecting with permission-denied (flag=false on grant).
Future<void> _permissionDeniedInvoker(String _, Map<String, dynamic> __) async {
  throw FirebaseFunctionsException(
    code: 'permission-denied',
    message: 'Tutor does not have permission for this grant',
  );
}

/// DNI-487 AC-6: the per-call AD-53 grant check rejects after the parent
/// turned "Can edit learning" off (writeWithChangeLog's exact wording).
Future<void> _editingTurnedOffInvoker(String _, Map<String, dynamic> __) async {
  throw FirebaseFunctionsException(
    code: 'permission-denied',
    message: 'Grant lacks can_edit_learning',
  );
}

/// Simulates a non-Firebase error (network failure etc.).
Future<void> _genericErrorInvoker(String _, Map<String, dynamic> __) async {
  throw Exception('network timeout');
}

// ── Helper ─────────────────────────────────────────────────────────────────

TutorWriteService _svc(TutorCallableInvoker invoker) =>
    TutorWriteService(invoker: invoker);

const _grantId = 'grant_abc';
const _ownerUid = 'parent_uid_123';
const _profileId = '01TESTPROFILEULID000000000';

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group(
    'S4 — TutorWriteService: permission-denied surfaces as TutorWriteFailure',
    () {
      // AC1 + AC2: CF rejects with permission-denied when flag=false.
      // The service must catch it and return TutorWriteFailure — not rethrow.
      group(
        'AC1+AC2: permission-denied → TutorWriteFailure(code=permission-denied)',
        () {
          test(
            'resetCompletion (can_reset_completion=false on grant)',
            () async {
              final result = await _svc(_permissionDeniedInvoker)
                  .resetCompletion(
                    grantId: _grantId,
                    ownerUid: _ownerUid,
                    profileId: _profileId,
                    completionId: 'comp_xyz',
                  );
              expect(result, isA<TutorWriteFailure>());
              expect((result as TutorWriteFailure).code, 'permission-denied');
            },
          );

          test('upsertGoal (can_edit_goals=false on grant)', () async {
            final result = await _svc(_permissionDeniedInvoker).upsertGoal(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              goalId: 'goal_1',
              goalData: {'target': 5},
            );
            expect(result, isA<TutorWriteFailure>());
            expect((result as TutorWriteFailure).code, 'permission-denied');
          });

          test('deleteGoal (can_edit_goals=false on grant)', () async {
            final result = await _svc(_permissionDeniedInvoker).deleteGoal(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              goalId: 'goal_1',
            );
            expect(result, isA<TutorWriteFailure>());
            expect((result as TutorWriteFailure).code, 'permission-denied');
          });

          test(
            'upsertStudyDayConfig (can_edit_study_days=false on grant)',
            () async {
              final result = await _svc(_permissionDeniedInvoker)
                  .upsertStudyDayConfig(
                    grantId: _grantId,
                    ownerUid: _ownerUid,
                    profileId: _profileId,
                    configId: 'cfg_1',
                    configData: {'day': 'sunday', 'enabled': true},
                  );
              expect(result, isA<TutorWriteFailure>());
              expect((result as TutorWriteFailure).code, 'permission-denied');
            },
          );

          test(
            'deleteStudyDayConfig (can_edit_study_days=false on grant)',
            () async {
              final result = await _svc(_permissionDeniedInvoker)
                  .deleteStudyDayConfig(
                    grantId: _grantId,
                    ownerUid: _ownerUid,
                    profileId: _profileId,
                    configId: 'cfg_1',
                  );
              expect(result, isA<TutorWriteFailure>());
              expect((result as TutorWriteFailure).code, 'permission-denied');
            },
          );

          test('upsertTrack (can_edit_stages=false on grant)', () async {
            final result = await _svc(_permissionDeniedInvoker).upsertTrack(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              trackId: 'track_1',
              trackData: {'curriculum_id': 'daf_yomi'},
            );
            expect(result, isA<TutorWriteFailure>());
            expect((result as TutorWriteFailure).code, 'permission-denied');
          });

          test(
            'updateGamificationSettings can_edit_rewards (flag=false on grant)',
            () async {
              final result = await _svc(_permissionDeniedInvoker)
                  .updateGamificationSettings(
                    grantId: _grantId,
                    ownerUid: _ownerUid,
                    profileId: _profileId,
                    permKey: 'can_edit_rewards',
                    settingsData: <String, dynamic>{
                      'reward_settings': <String, dynamic>{},
                    },
                  );
              expect(result, isA<TutorWriteFailure>());
              expect((result as TutorWriteFailure).code, 'permission-denied');
            },
          );

          test(
            'updateGamificationSettings can_edit_points (flag=false on grant)',
            () async {
              final result = await _svc(_permissionDeniedInvoker)
                  .updateGamificationSettings(
                    grantId: _grantId,
                    ownerUid: _ownerUid,
                    profileId: _profileId,
                    permKey: 'can_edit_points',
                    settingsData: <String, dynamic>{
                      'points_config': <String>[],
                    },
                  );
              expect(result, isA<TutorWriteFailure>());
              expect((result as TutorWriteFailure).code, 'permission-denied');
            },
          );
        },
      );

      // AC3: successful calls return TutorWriteSuccess.
      group('AC3: success → TutorWriteSuccess', () {
        test(
          'resetCompletion succeeds when can_reset_completion=true',
          () async {
            final result = await _svc(_successInvoker).resetCompletion(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              completionId: 'comp_xyz',
            );
            expect(result, isA<TutorWriteSuccess>());
          },
        );

        test('upsertGoal succeeds when can_edit_goals=true', () async {
          final result = await _svc(_governedSuccessInvoker).upsertGoal(
            grantId: _grantId,
            ownerUid: _ownerUid,
            profileId: _profileId,
            goalId: 'goal_1',
            goalData: {'target': 5},
          );
          expect(result, isA<TutorWriteSuccess>());
        });

        test(
          'editProfile succeeds (always allowed — no permission flag)',
          () async {
            final result = await _svc(_successInvoker).editProfile(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              displayName: 'Yosef',
            );
            expect(result, isA<TutorWriteSuccess>());
          },
        );
      });

      // AC4: non-Firebase errors also surface as TutorWriteFailure.
      group('AC4: generic error → TutorWriteFailure (no rethrow)', () {
        test(
          // AUD-tutoring-11: a stable code + fixed message, never the raw
          // exception text (EH-5) — a Hebrew UI sentence must not end in an
          // untranslated fragment.
          'generic exception → TutorWriteFailure with stable code, no raw '
          'exception text',
          () async {
            final result = await _svc(_genericErrorInvoker).upsertGoal(
              grantId: _grantId,
              ownerUid: _ownerUid,
              profileId: _profileId,
              goalId: 'goal_1',
              goalData: {'target': 5},
            );
            expect(result, isA<TutorWriteFailure>());
            final failure = result as TutorWriteFailure;
            expect(failure.code, 'unknown-error');
            expect(failure.message, isNot(contains('network timeout')));
          },
        );
      });
    },
  );

  // ── DNI-487 AC-6: revocation applies on the next write call ───────────────

  group('DNI-487 AC-6 — parent turned off editing', () {
    Future<TutorWriteResult> writeAfterRevocation() =>
        _svc(_editingTurnedOffInvoker).upsertGoal(
          grantId: _grantId,
          ownerUid: _ownerUid,
          profileId: _profileId,
          goalId: 'goal_1',
          goalData: {'target': 5},
        );

    test('the rejection maps to TutorWriteEditingTurnedOff', () async {
      final result = await writeAfterRevocation();
      expect(result, isA<TutorWriteEditingTurnedOff>());
      expect((result as TutorWriteFailure).code, 'permission-denied');
    });

    test(
      'the tutor sees "{learner}\'s parent has turned off editing"',
      () async {
        final result = await writeAfterRevocation() as TutorWriteFailure;
        expect(
          tutorWriteFailureMessage(
            AppLocalizationsEn(),
            result,
            learnerName: 'Moshe',
          ),
          "Moshe's parent has turned off editing",
        );
        expect(
          tutorWriteFailureMessage(
            AppLocalizationsHe(),
            result,
            learnerName: 'משה',
          ),
          'ההורה של משה כיבה את העריכה',
        );
      },
    );

    test('other permission denials keep the generic copy', () async {
      final result =
          await _svc(_permissionDeniedInvoker).upsertGoal(
                grantId: _grantId,
                ownerUid: _ownerUid,
                profileId: _profileId,
                goalId: 'goal_1',
                goalData: {'target': 5},
              )
              as TutorWriteFailure;
      expect(result, isNot(isA<TutorWriteEditingTurnedOff>()));
      expect(
        tutorWriteFailureMessage(
          AppLocalizationsEn(),
          result,
          learnerName: 'Moshe',
        ),
        "You don't have permission to make this edit",
      );
    });
  });

  // ── DNI-486: the Story 1.23 learning commands share the failure mapping ──

  group('DNI-486 — learning commands surface permission failures typed', () {
    const event = TutorLearnEvent(
      id: '01JQ3K5M8N2P4R6T7V9X0Z1AB1',
      curriculumId: 'mishnayos',
      ref: 'Mishnah Berakhot 2:1',
      dateState: DateState.dated,
      learnedOn: '2026-10-01',
    );
    const voidId = '01JQ3K5M8N2P4R6T7V9X0Z1AB2';

    Map<String, Future<TutorWriteResult> Function(TutorWriteService)>
    commands() => {
      'recordLearning': (s) => s.recordLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        events: const [event],
      ),
      'voidLearning': (s) => s.voidLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: voidId,
        targetId: event.id,
      ),
      'replaceLearning': (s) => s.replaceLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: voidId,
        targetId: event.id,
        replacement: event,
      ),
      'unlearn': (s) => s.unlearn(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        actionId: voidId,
        curriculumId: 'mishnayos',
        leafSet: const ['Mishnah Berakhot 2:1'],
      ),
    };

    for (final MapEntry(key: name, value: run) in commands().entries) {
      test('$name: permission-denied → TutorWriteFailure', () async {
        final result = await run(_svc(_permissionDeniedInvoker));
        expect(result, isA<TutorWriteFailure>());
        expect((result as TutorWriteFailure).code, 'permission-denied');
        expect(result.isRetryable, isFalse);
      });

      test('$name: editing turned off → TutorWriteEditingTurnedOff', () async {
        expect(
          await run(_svc(_editingTurnedOffInvoker)),
          isA<TutorWriteEditingTurnedOff>(),
        );
      });

      test('$name: success → TutorLearningWritten', () async {
        expect(
          await run(_svc(_learningSuccessInvoker)),
          isA<TutorLearningWritten>(),
        );
      });

      test('$name: an answer that is not a validated success → retryable '
          'TutorWriteInvalidResponse', () async {
        final result = await run(_svc(_successInvoker));
        expect(result, isA<TutorWriteInvalidResponse>());
        expect((result as TutorWriteFailure).isRetryable, isTrue);
      });
    }
  });
}
