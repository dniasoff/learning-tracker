// V3-C — UI gating (R1 M1, R3 M1, R3 M2)
//
// Verifies that:
//   R1 M1 — point_config_screen watches activeTutorPermissionsProvider,
//            gates the _SaveBar on canEditPoints, and shows tutorPermissionDenied
//            snackbar when !canEdit.
//   R1 M1 — reward_configuration_screen watches activeTutorPermissionsProvider,
//            gates the save button on canEditRewards, and shows
//            tutorPermissionDenied snackbar when !canEdit.
//   R3 M1/M2 — edit_track_screen gates the save button on
//               canEditLearning (AD-53) and shows tutorPermissionDenied
//               snackbar when blocked.
//
// The add_track_flow_screen / TutorWriteException-catching coverage this
// file originally had (R3 M1) was retired 2026-08-18: TutorWriteException
// was deleted as dead code in 9d3eb81b ("Wave A3 remainder + orphaned
// TutorWriteException cleanup") — it was thrown only by
// tutored_write_router.dart, itself deleted earlier (Wave 0, blocker #15:
// "tutor writes currently have no client path at all"). That commit's own
// framing was "record it, do not invent a replacement" — there is no
// successor mechanism to test. edit_track_screen's TutorWriteException
// catch was removed the same way; its learning-edit UI-gating
// coverage (still real, still enforced) is unaffected and stays below.

@Tags(['v3c', 'tutor_mode', 'ui_gating'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String pointConfigSrc;
  late String rewardConfigSrc;
  late String editTrackSrc;

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
  });

  // ── R3 M1 + M2: edit_track_screen ────────────────────────────────────────

  group('R3 M1+M2 — edit_track_screen: canEditLearning', () {
    test('imports tutoring barrel', () {
      expect(
        editTrackSrc,
        contains("'package:learning_tracker/features/tutoring/tutoring.dart'"),
        reason:
            'edit_track_screen must import tutoring.dart to access '
            'activeTutorPermissionsProvider (R3 M1+M2)',
      );
    });

    test('watches the tutor write availability (DNI-486)', () {
      expect(
        editTrackSrc,
        contains('tutorWriteAvailabilityProvider'),
        reason:
            'edit_track_screen must gate Save on the tutor write '
            'availability: AD-53 canEditLearning, a positive connectivity '
            'probe and the talmid outside a lock (DNI-486)',
      );
    });

    test('derives canSave from the availability', () {
      expect(
        editTrackSrc,
        contains(
          'canSave = ref.watch(tutorWriteAvailabilityProvider).allowsWrite',
        ),
        reason:
            'AD-53: one permission gates every learning edit (and DNI-486 '
            'adds online-only and the lock), null-safe for owners',
      );
    });

    test('save button onPressed gated on canSave', () {
      expect(
        editTrackSrc,
        contains('onPressed: canSave'),
        reason:
            'save button onPressed must be conditioned on canSave — '
            'restricted tutors must not trigger track/goal saves (R3 M1+M2)',
      );
    });

    test('a blocked Save stays visible but disabled under the tutor note '
        '(DNI-486 AC-4)', () {
      expect(editTrackSrc, contains('TutorDisabledControl('));
      expect(editTrackSrc, contains('TutorWriteNote('));
    });
  });
}
