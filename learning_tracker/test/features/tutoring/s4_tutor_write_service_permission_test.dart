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
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';

// ── Fake invokers ──────────────────────────────────────────────────────────

/// Simulates a successful CF call.
Future<void> _successInvoker(String _, Map<String, dynamic> __) async {}

/// Simulates the CF rejecting with permission-denied (flag=false on grant).
Future<void> _permissionDeniedInvoker(String _, Map<String, dynamic> __) async {
  throw FirebaseFunctionsException(
    code: 'permission-denied',
    message: 'Tutor does not have permission for this grant',
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
          final result = await _svc(_successInvoker).upsertGoal(
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
}
