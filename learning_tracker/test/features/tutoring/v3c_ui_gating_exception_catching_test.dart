// V3-C — UI gating + exception catching (R1 M1, R3 M1, R3 M2)
//
// Verifies that:
//   R1 M1 — point_config_screen watches activeTutorPermissionsProvider,
//            gates the _SaveBar on canEditPoints, and shows tutorPermissionDenied
//            snackbar when !canEdit.
//   R1 M1 — reward_configuration_screen watches activeTutorPermissionsProvider,
//            gates the save button on canEditRewards, and shows
//            tutorPermissionDenied snackbar when !canEdit.
//   R3 M1 — add_track_flow_screen._finishFlow catches TutorWriteException and
//            shows tutorPermissionDenied snackbar on permission-denied code.
//   R3 M1/M2 — edit_track_screen._save catches TutorWriteException, gates save
//               button on canEditGoals && canEditStages, and shows
//               tutorPermissionDenied snackbar.

@Tags(['v3c', 'tutor_mode', 'ui_gating'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String pointConfigSrc;
  late String rewardConfigSrc;
  late String editTrackSrc;
  late String addTrackFlowSrc;

  setUpAll(() {
    pointConfigSrc = File(
      'lib/features/gamification/presentation/screens/point_config_screen.dart',
    ).readAsStringSync();

    rewardConfigSrc = File(
      'lib/features/gamification/presentation/screens/reward_configuration_screen.dart',
    ).readAsStringSync();

    editTrackSrc = File(
      'lib/features/tracks/setup/presentation/screens/edit_track_screen.dart',
    ).readAsStringSync();

    addTrackFlowSrc = File(
      'lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart',
    ).readAsStringSync();
  });

  // ── R1 M1: point_config_screen ────────────────────────────────────────────

  group('R1 M1 — point_config_screen: canEditPoints gating', () {
    test('watches activeTutorPermissionsProvider', () {
      expect(
        pointConfigSrc,
        contains('activeTutorPermissionsProvider'),
        reason:
            'point_config_screen must watch activeTutorPermissionsProvider '
            'to derive canEditPoints (R1 M1)',
      );
    });

    test('derives canEditPoints from tutorPerms', () {
      expect(
        pointConfigSrc,
        contains('canEditPoints'),
        reason:
            'point_config_screen must derive canEditPoints from tutorPerms '
            'to gate the save affordance (R1 M1)',
      );
    });

    test('_SaveBar enabled condition includes canEdit', () {
      expect(
        pointConfigSrc,
        contains('enabled: _hasPendingEdits && !_saving && canEdit'),
        reason:
            '_SaveBar must not be enabled when canEdit is false — '
            'tutors without canEditPoints must not save point config (R1 M1)',
      );
    });

    test('shows tutorPermissionDenied snackbar when !canEdit', () {
      expect(
        pointConfigSrc,
        contains('tutorPermissionDenied'),
        reason:
            'point_config_screen must show tutorPermissionDenied snackbar '
            'when the save affordance is tapped but !canEdit (R1 M1)',
      );
    });

    test('canEdit guard pattern is null-safe (owner always can edit)', () {
      expect(
        pointConfigSrc,
        contains('tutorPerms == null || tutorPerms.canEditPoints'),
        reason:
            'canEditPoints guard must be null-safe: null tutorPerms '
            '(no tutored session) means the owner is editing — always allowed (R1 M1)',
      );
    });

    test('increment callback is nullable (disabled when !canEdit)', () {
      // The _StepperControl.onIncrement and _CurriculumPointsCard.onIncrement
      // must be VoidCallback? so null can be passed when !canEdit.
      expect(
        pointConfigSrc,
        contains('VoidCallback?'),
        reason:
            'Stepper/card increment callbacks must be VoidCallback? '
            'so null disables the affordance for restricted tutors (R1 M1)',
      );
    });
  });

  // ── R1 M1: reward_configuration_screen ───────────────────────────────────

  group('R1 M1 — reward_configuration_screen: canEditRewards gating', () {
    test('watches activeTutorPermissionsProvider', () {
      expect(
        rewardConfigSrc,
        contains('activeTutorPermissionsProvider'),
        reason:
            'reward_configuration_screen must watch activeTutorPermissionsProvider '
            'to derive canEditRewards (R1 M1)',
      );
    });

    test('derives canEditRewards from tutorPerms', () {
      expect(
        rewardConfigSrc,
        contains('canEditRewards'),
        reason:
            'reward_configuration_screen must derive canEditRewards from '
            'tutorPerms (R1 M1)',
      );
    });

    test('save button gated on canEdit', () {
      // The save FilledButton.onPressed must use canEdit to decide between
      // the real save action and the permission-denied snackbar branch.
      expect(
        rewardConfigSrc,
        contains('onPressed: canEdit'),
        reason:
            'save FilledButton.onPressed must be conditioned on canEdit — '
            'restricted tutors must not be able to save reward config (R1 M1)',
      );
    });

    test('shows tutorPermissionDenied snackbar when !canEdit', () {
      expect(
        rewardConfigSrc,
        contains('tutorPermissionDenied'),
        reason:
            'reward_configuration_screen must show tutorPermissionDenied '
            'snackbar when save is tapped but !canEdit (R1 M1)',
      );
    });

    test('canEdit guard pattern is null-safe (owner always can edit)', () {
      expect(
        rewardConfigSrc,
        contains('tutorPerms == null || tutorPerms.canEditRewards'),
        reason:
            'canEditRewards guard must be null-safe so owners are never blocked '
            'by the absence of tutorPerms (R1 M1)',
      );
    });

    test('already catches TutorWriteException in _saveReward', () {
      expect(
        rewardConfigSrc,
        contains('on TutorWriteException catch'),
        reason:
            'reward_configuration_screen must catch TutorWriteException on '
            'CF failure to surface permission errors gracefully (R1 M1)',
      );
    });
  });

  // ── R3 M1: add_track_flow_screen ─────────────────────────────────────────

  group('R3 M1 — add_track_flow_screen: TutorWriteException catching', () {
    test('imports tutoring barrel', () {
      expect(
        addTrackFlowSrc,
        contains("'package:learning_tracker/features/tutoring/tutoring.dart'"),
        reason:
            'add_track_flow_screen must import tutoring.dart to access '
            'TutorWriteException for the goal-write error path (R3 M1)',
      );
    });

    test('_finishFlow catches TutorWriteException', () {
      expect(
        addTrackFlowSrc,
        contains('on TutorWriteException catch'),
        reason:
            '_finishFlow must catch TutorWriteException so that CF permission '
            'rejections during track creation do not crash the screen (R3 M1)',
      );
    });

    test('shows tutorPermissionDenied snackbar on permission-denied code', () {
      expect(
        addTrackFlowSrc,
        contains('tutorPermissionDenied'),
        reason:
            'add_track_flow_screen must show tutorPermissionDenied snackbar '
            "when TutorWriteException.code == 'permission-denied' (R3 M1)",
      );
    });

    test("checks for 'permission-denied' error code", () {
      expect(
        addTrackFlowSrc,
        contains("e.code == 'permission-denied'"),
        reason:
            'The catch must check e.code to distinguish permission denials '
            'from other CF failures (R3 M1)',
      );
    });

    test('TutorWriteException catch precedes generic catch', () {
      final tutorCatchIdx = addTrackFlowSrc.indexOf(
        'on TutorWriteException catch',
      );
      final genericCatchIdx = addTrackFlowSrc.indexOf('} catch (e)');
      expect(
        tutorCatchIdx,
        greaterThan(0),
        reason: 'TutorWriteException catch block must exist',
      );
      expect(
        tutorCatchIdx < genericCatchIdx,
        isTrue,
        reason:
            'TutorWriteException must be caught before the generic catch block '
            'so it is not silently swallowed (R3 M1)',
      );
    });
  });

  // ── R3 M1 + M2: edit_track_screen ────────────────────────────────────────

  group(
    'R3 M1+M2 — edit_track_screen: canEditGoals/canEditStages + TutorWriteException',
    () {
      test('imports tutoring barrel', () {
        expect(
          editTrackSrc,
          contains(
            "'package:learning_tracker/features/tutoring/tutoring.dart'",
          ),
          reason:
              'edit_track_screen must import tutoring.dart to access '
              'activeTutorPermissionsProvider and TutorWriteException (R3 M1+M2)',
        );
      });

      test('watches activeTutorPermissionsProvider', () {
        expect(
          editTrackSrc,
          contains('activeTutorPermissionsProvider'),
          reason:
              'edit_track_screen must watch activeTutorPermissionsProvider '
              'to derive canEditGoals + canEditStages (R3 M1+M2)',
        );
      });

      test('derives canEditGoals from tutorPerms', () {
        expect(
          editTrackSrc,
          contains('canEditGoals'),
          reason:
              'edit_track_screen must derive canEditGoals to gate the save '
              'affordance and the goal-write path (R3 M1)',
        );
      });

      test('derives canEditStages from tutorPerms', () {
        expect(
          editTrackSrc,
          contains('canEditStages'),
          reason:
              'edit_track_screen must derive canEditStages to gate the save '
              'affordance for stage/track writes (R3 M2)',
        );
      });

      test(
        'derives canSave as conjunction of canEditGoals and canEditStages',
        () {
          expect(
            editTrackSrc,
            contains('canSave = canEditGoals && canEditStages'),
            reason:
                'canSave must be the conjunction of both flags — the save button '
                'is disabled if either flag is false (R3 M1+M2)',
          );
        },
      );

      test('save button onPressed gated on canSave', () {
        expect(
          editTrackSrc,
          contains('onPressed: canSave'),
          reason:
              'save button onPressed must be conditioned on canSave — '
              'restricted tutors must not trigger track/goal saves (R3 M1+M2)',
        );
      });

      test('shows tutorPermissionDenied snackbar when !canSave', () {
        expect(
          editTrackSrc,
          contains('tutorPermissionDenied'),
          reason:
              'edit_track_screen must show tutorPermissionDenied snackbar '
              'when save is tapped but !canSave (R3 M1+M2)',
        );
      });

      test('_save catches TutorWriteException', () {
        expect(
          editTrackSrc,
          contains('on TutorWriteException catch'),
          reason:
              '_save must catch TutorWriteException so CF permission denials '
              'from tutored goal/track writes do not crash the screen (R3 M2)',
        );
      });

      test("_save checks for 'permission-denied' code", () {
        expect(
          editTrackSrc,
          contains("e.code == 'permission-denied'"),
          reason:
              'The TutorWriteException catch must inspect e.code to show '
              'the right user message for permission failures (R3 M2)',
        );
      });

      test('canEdit guard pattern is null-safe for goals', () {
        expect(
          editTrackSrc,
          contains('tutorPerms == null || tutorPerms.canEditGoals'),
          reason:
              'canEditGoals guard must be null-safe so owners are never blocked '
              'when no tutored session is active (R3 M1)',
        );
      });

      test('canEdit guard pattern is null-safe for stages', () {
        expect(
          editTrackSrc,
          contains('tutorPerms == null || tutorPerms.canEditStages'),
          reason:
              'canEditStages guard must be null-safe so owners are never blocked '
              'when no tutored session is active (R3 M2)',
        );
      });
    },
  );
}
