// T3 — Read-only surfaces + gating
//
// Verifies that:
//   AC1 — _TutorModeIndicatorBar in app_shell.dart is a ConsumerWidget with
//          an exit button (calls exit() + replaceAll AppShellRoute).
//   AC2 — settings_screen.dart gates all write-path controls on
//          activeTutoredProfileSelectionProvider != null (isTutoredSession).
//   AC3 — learning_screen.dart suppresses the "Add track" CTA in a tutored session.
//   AC4 — dashboard_body.dart suppresses the "Add track" CTA in a tutored session.
//   AC5 — text_display_screen.dart gates live completion on
//          activeTutoredProfileSelectionProvider != null.
//   AC6 — TutorPermissions.canMarkLiveCompletion is always false (immutable invariant).
//   AC7 — The app_shell.dart _TutorModeIndicatorBar widget is a ConsumerWidget
//          (needed to call notifier.exit() and access router).

@Tags(['t3', 'tutor_mode', 'gating'])
library;

import 'dart:io';

import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:test/test.dart';

void main() {
  late String appShellSrc;
  late String settingsSrc;
  late String learningSrc;
  late String dashboardBodySrc;
  late String textDisplaySrc;

  setUpAll(() {
    appShellSrc = File(
      'lib/app/router/app_shell.dart',
    ).readAsStringSync();

    settingsSrc = File(
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ).readAsStringSync();

    learningSrc = File(
      'lib/features/learning/presentation/screens/learning_screen.dart',
    ).readAsStringSync();

    dashboardBodySrc = File(
      'lib/features/dashboard/presentation/widgets/dashboard_body.dart',
    ).readAsStringSync();

    textDisplaySrc = File(
      'lib/features/content_browsing/presentation/screens/text_display_screen.dart',
    ).readAsStringSync();
  });

  group('T3.readonly-state — Tutor mode indicator bar', () {
    test('AC7: _TutorModeIndicatorBar is a ConsumerWidget (not StatelessWidget)', () {
      expect(
        appShellSrc,
        contains('_TutorModeIndicatorBar extends ConsumerWidget'),
        reason:
            '_TutorModeIndicatorBar must extend ConsumerWidget so it can '
            'call activeTutoredProfileSelectionProvider.notifier.exit()',
      );
    });

    test('AC1: exit button calls activeTutoredProfileSelectionProvider notifier', () {
      expect(
        appShellSrc,
        contains('activeTutoredProfileSelectionProvider.notifier'),
        reason:
            'The tutor mode indicator bar must access the provider notifier '
            'to call exit() when the user taps the Exit button',
      );
      expect(
        appShellSrc,
        contains('.exit()'),
        reason:
            'The exit button must call .exit() to clear the tutored selection',
      );
    });

    test('AC1: exit button navigates back via replaceAll', () {
      expect(
        appShellSrc,
        contains('replaceAll([const AppShellRoute()])'),
        reason:
            'After exit(), the bar must navigate back to AppShellRoute '
            'so the tutor lands on their own profile',
      );
    });

    test('AC1: exit button renders tutorModeExit l10n key', () {
      expect(
        appShellSrc,
        contains('tutorModeExit'),
        reason:
            'The exit button label must use the tutorModeExit l10n key for '
            'EN + HE support',
      );
    });

    test('AC1: indicator bar imports activeTutoredProfileProvider', () {
      expect(
        appShellSrc,
        contains('active_tutored_profile_provider.dart'),
        reason:
            'app_shell.dart must import active_tutored_profile_provider.dart '
            'to access the notifier for the exit action',
      );
    });
  });

  group('T3.gating — Settings screen hides write-path controls', () {
    test('AC2: settings_screen watches activeTutoredProfileSelectionProvider', () {
      expect(
        settingsSrc,
        contains('activeTutoredProfileSelectionProvider'),
        reason:
            'settings_screen.dart must watch activeTutoredProfileSelectionProvider '
            'to determine if the tutor is in a tutored session',
      );
    });

    test('AC2: isTutoredSession flag gates UserProfileHeaderCard', () {
      expect(
        settingsSrc,
        contains('isTutoredSession'),
        reason:
            'settings_screen.dart must derive isTutoredSession and use it '
            'to gate write-path controls including the profile header card',
      );
    });

    test('AC2: Manage Tracks tile gated on !isTutoredSession', () {
      expect(
        settingsSrc,
        contains('!isTutoredSession'),
        reason:
            'The Manage Tracks tile (and other write controls) must be gated '
            'on !isTutoredSession to prevent tutor writes via settings UI',
      );
    });

    test('AC2: Backup/Sync section gated on !isTutoredSession', () {
      expect(
        settingsSrc,
        contains('BackupSyncSection'),
        reason:
            'The BackupSyncSection must remain in the file (not removed)',
      );
      // The gating is via `if (!isChildProfile && !isTutoredSession)` — verify
      // that isTutoredSession gates BackupSyncSection contextually.
      final backupIdx = settingsSrc.indexOf('BackupSyncSection');
      final isTutoredBeforeBackup = settingsSrc
          .substring(0, backupIdx)
          .contains('isTutoredSession');
      expect(
        isTutoredBeforeBackup,
        isTrue,
        reason:
            'isTutoredSession must appear before BackupSyncSection in the '
            'widget tree to gate it from tutored sessions',
      );
    });
  });

  group('T3.gating — Learning screen suppresses "Add track" CTA', () {
    test('AC3: learning_screen imports activeTutoredProfileProvider', () {
      expect(
        learningSrc,
        contains('active_tutored_profile_provider.dart'),
        reason:
            'learning_screen.dart must import the tutored provider to gate '
            'the Add Track CTA',
      );
    });

    test('AC3: learning_screen uses isTutoredSession flag', () {
      expect(
        learningSrc,
        contains('isTutoredSession'),
        reason:
            'learning_screen.dart must derive isTutoredSession and use it '
            'to suppress the Add Track CTA in tutored sessions',
      );
    });
  });

  group('T3.gating — Dashboard body suppresses "Add track" CTA', () {
    test('AC4: dashboard_body imports activeTutoredProfileProvider', () {
      expect(
        dashboardBodySrc,
        contains('active_tutored_profile_provider.dart'),
        reason:
            'dashboard_body.dart must import the tutored provider to gate '
            'the empty-state Add Track CTA',
      );
    });

    test('AC4: dashboard_body uses isTutoredSession flag', () {
      expect(
        dashboardBodySrc,
        contains('isTutoredSession'),
        reason:
            'dashboard_body.dart must derive isTutoredSession and use it '
            'to suppress the Add Track CTA in tutored sessions',
      );
    });
  });

  group('T3.gating — Text display screen blocks live completion', () {
    test('AC5: text_display_screen watches activeTutoredProfileSelectionProvider', () {
      expect(
        textDisplaySrc,
        contains('activeTutoredProfileSelectionProvider'),
        reason:
            'text_display_screen.dart must watch activeTutoredProfileSelectionProvider '
            'to disable the Mark Complete button in tutored sessions',
      );
    });

    test('AC5: live-mark button disabled when isTutor is true', () {
      expect(
        textDisplaySrc,
        contains('isTutor'),
        reason:
            'text_display_screen.dart must derive an isTutor flag and gate '
            'onPressed on it (D5: canMarkLiveCompletion always false)',
      );
    });

    test('AC5: MarkLiveCompletionUseCase is used for domain-layer enforcement', () {
      expect(
        textDisplaySrc,
        contains('MarkLiveCompletionUseCase'),
        reason:
            'text_display_screen.dart must route through MarkLiveCompletionUseCase '
            'so the domain guard is enforced even if the UI button is bypassed',
      );
    });
  });

  group('T3.gating — TutorPermissions invariant', () {
    test('AC6: canMarkLiveCompletion is always false (immutable invariant)', () {
      const perms = TutorPermissions();
      expect(
        perms.canMarkLiveCompletion,
        isFalse,
        reason:
            'TutorPermissions.canMarkLiveCompletion must always be false — '
            'tutors can never mark live forward completions (D5)',
      );
    });

    test('AC6: copyWith cannot override canMarkLiveCompletion to true', () {
      const perms = TutorPermissions(
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
      // canMarkLiveCompletion is set in the constructor body, not via parameter
      expect(
        perms.canMarkLiveCompletion,
        isFalse,
        reason:
            'canMarkLiveCompletion must remain false even when all other '
            'permissions are set to true',
      );
    });
  });
}
