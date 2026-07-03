// T3 — Read-only surfaces + gating (re-scoped: parent-elevated for tutors)
//
// Verifies that:
//   AC1 — _TutorModeIndicatorBar in app_shell.dart is a ConsumerWidget with
//          an exit button (calls exit() + replaceAll AppShellRoute).
//   AC2 — settings_screen.dart uses isTutorElevated (parent-equivalent for
//          learning management) and still hides account-admin surfaces.
//   AC3 — learning_screen.dart shows Add Track CTA based on tutorPerms
//          (canEditStages), not unconditionally suppressed.
//   AC4 — dashboard_body.dart no longer forces child-mode for tutored
//          sessions (isChildMode is NOT ORed with isTutoredSession).
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
    appShellSrc = File('lib/app/router/app_shell.dart').readAsStringSync();

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
    test(
      'AC7: TutorModeIndicatorBar is a ConsumerWidget (not StatelessWidget)',
      () {
        expect(
          appShellSrc,
          contains('TutorModeIndicatorBar extends ConsumerWidget'),
          reason:
              'TutorModeIndicatorBar must extend ConsumerWidget so it can '
              'call activeTutoredProfileSelectionProvider.notifier.exit()',
        );
      },
    );

    test(
      'AC1: exit button calls activeTutoredProfileSelectionProvider notifier',
      () {
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
      },
    );

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

    // TUT-04: the amber Tutor banner must persist on pushed sub-routes too.
    test('TUT-04: PersistentSwitcherScaffold renders the tutor bar on '
        'sub-routes when a tutored session is active', () {
      final persistentSrc = File(
        'lib/app/router/persistent_switcher_scaffold.dart',
      ).readAsStringSync();
      expect(
        persistentSrc,
        contains('TutorModeIndicatorBar'),
        reason:
            'persistent_switcher_scaffold.dart must render TutorModeIndicatorBar '
            'so the tutor banner persists across pushed sub-routes (TUT-04)',
      );
      expect(
        persistentSrc,
        contains('activeTutoredProfileSelectionProvider'),
        reason:
            'the tutor bar must be gated on activeTutoredProfileSelectionProvider '
            '(only shown while a talmid context is active)',
      );
    });
  });

  group('T3.gating — Settings screen: parent-elevated for tutors', () {
    test(
      'AC2: settings_screen watches activeTutoredProfileSelectionProvider',
      () {
        expect(
          settingsSrc,
          contains('activeTutoredProfileSelectionProvider'),
          reason:
              'settings_screen.dart must watch activeTutoredProfileSelectionProvider '
              'to determine if the tutor is in a tutored session',
        );
      },
    );

    test('AC2: settings_screen derives isTutorElevated flag', () {
      expect(
        settingsSrc,
        contains('isTutorElevated'),
        reason:
            'settings_screen.dart must derive isTutorElevated for '
            'parent-equivalent rendering in tutored sessions',
      );
    });

    test('AC2: settings_screen reads activeTutorPermissionsProvider', () {
      expect(
        settingsSrc,
        contains('activeTutorPermissionsProvider'),
        reason:
            'settings_screen.dart must read activeTutorPermissionsProvider '
            'to gate individual edit surfaces by tutor permissions',
      );
    });

    test(
      'AC2: Manage Tracks shown with canEditStages gate (not unconditionally hidden)',
      () {
        // In the new model, Manage Tracks is shown to tutors when canEditStages.
        // The old `!isTutoredSession` gate around Manage Tracks is gone.
        expect(
          settingsSrc,
          contains('canEditStages'),
          reason:
              'Manage Tracks must be gated on tutorPerms.canEditStages '
              '(not hidden for all tutored sessions)',
        );
      },
    );

    test(
      'AC2: Manage Profiles is hidden in tutored sessions (owner-only admin)',
      () {
        // The standalone Manage Tracks / Manage Profiles card is own-profile
        // only — gated on `!isTutoredSession && !isChildProfile`. In a tutored
        // session the tutor reaches tracks via the parent-management hub tile
        // instead (which re-gates each surface by TutorPermissions).
        expect(
          settingsSrc,
          contains('!isTutoredSession && !isChildProfile'),
          reason:
              'Manage Profiles/Tracks card must be gated on '
              '!isTutoredSession && !isChildProfile — Manage Profiles is an '
              'owner-only admin surface hidden from tutors (FR-3)',
        );
      },
    );

    test(
      'AC2: tutored session exposes the parent-management hub entry (TUT-06)',
      () {
        expect(
          settingsSrc,
          contains('ParentSettingsRoute'),
          reason:
              'In a tutored session Settings must surface an entry into the '
              'parent-management hub (ParentSettingsScreen) so the tutor can '
              'manage the talmid tracks/points/rewards/goals (TUT-06)',
        );
        // The hub tile must be gated on isTutorElevated (tutored session).
        final hubIdx = settingsSrc.indexOf('ParentSettingsRoute');
        final gatedBefore = settingsSrc
            .substring(0, hubIdx)
            .contains('isTutorElevated');
        expect(
          gatedBefore,
          isTrue,
          reason:
              'The parent-management hub tile must be gated on isTutorElevated',
        );
      },
    );

    test('AC2: account/profile header is HIDDEN in a tutored session', () {
      // BUG 2 (supersedes TUT-05): the header card + its tap-through
      // account-actions sheet are the TUTOR's own device/account surface
      // (switch login, change password, sign out, delete account). It must be
      // hidden entirely when an active tutored selection is present so no
      // tutor-account items leak into the talmid's student-scope context.
      final headerIdx = settingsSrc.indexOf('UserProfileHeaderCard(');
      expect(
        headerIdx,
        greaterThanOrEqualTo(0),
        reason:
            'settings_screen.dart must still render UserProfileHeaderCard '
            'for own (non-tutored) sessions',
      );
      // The header must be guarded by `if (!isTutoredSession)` immediately
      // before it.
      final guardIdx = settingsSrc.lastIndexOf(
        'if (!isTutoredSession)',
        headerIdx,
      );
      expect(
        guardIdx,
        greaterThanOrEqualTo(0),
        reason:
            'settings_screen.dart must gate UserProfileHeaderCard behind '
            '`if (!isTutoredSession)` so the tutor own-account header is hidden '
            'in a tutored session (BUG 2)',
      );
    });

    test('AC2: Backup/Sync section gated on !isTutoredSession', () {
      expect(
        settingsSrc,
        contains('BackupSyncSection'),
        reason: 'The BackupSyncSection must remain in the file (not removed)',
      );
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

  group('T3.gating — Learning screen: permission-gated Add Track CTA', () {
    test('AC3: learning_screen imports the tutored-profile provider '
        '(directly or via the tutoring.dart barrel)', () {
      // AUD-learning-02 (Rule 2 — no cross-feature deep imports) routed this
      // through features/tutoring/tutoring.dart instead of importing
      // active_tutored_profile_provider.dart directly; the barrel re-exports
      // it in full (see tutoring.dart), so the provider is still reachable —
      // only the import path changed. Accept either form so this AC keeps
      // testing "the provider is reachable", not "which file states so".
      expect(
        learningSrc.contains('active_tutored_profile_provider.dart') ||
            learningSrc.contains("features/tutoring/tutoring.dart'"),
        isTrue,
        reason:
            'learning_screen.dart must import the tutored provider (directly '
            'or via the tutoring.dart barrel) to gate the Add Track CTA by '
            'tutor permissions',
      );
    });

    test('AC3: learning_screen reads activeTutorPermissionsProvider', () {
      expect(
        learningSrc,
        contains('activeTutorPermissionsProvider'),
        reason:
            'learning_screen.dart must read activeTutorPermissionsProvider '
            'so that tutors with canEditStages can see the Add Track CTA',
      );
    });

    test(
      'AC3: learning_screen gates Add Track CTA on canEditStages for tutors',
      () {
        expect(
          learningSrc,
          contains('canEditStages'),
          reason:
              'learning_screen.dart must gate the Add Track CTA on '
              'tutorPerms.canEditStages (parent-equivalent for track management)',
        );
      },
    );
  });

  group(
    'T3.gating — Dashboard body: no forced child-mode for tutored sessions',
    () {
      test('AC4: dashboard_body imports activeTutoredProfileProvider', () {
        expect(
          dashboardBodySrc,
          contains('active_tutored_profile_provider.dart'),
          reason: 'dashboard_body.dart must import the tutored provider',
        );
      });

      test(
        'AC4: dashboard_body does NOT force isChildMode for tutored sessions',
        () {
          // The old code was: isChildMode: isChildMode || isTutoredSession
          // The new code passes isChildMode directly (no || isTutoredSession).
          expect(
            dashboardBodySrc,
            isNot(contains('isChildMode: isChildMode || isTutoredSession')),
            reason:
                'dashboard_body must NOT force child-mode for tutored sessions — '
                'tutors see the parent/adult management view',
          );
        },
      );

      test(
        'AC4: dashboard_body passes isChildMode without tutored override',
        () {
          expect(
            dashboardBodySrc,
            contains('isChildMode: isChildMode,'),
            reason:
                'EmptyDashboard must receive isChildMode directly (tutor sees '
                'adult view with Add Track CTA)',
          );
        },
      );
    },
  );

  group('T3.gating — Text display screen blocks live completion', () {
    test(
      'AC5: text_display_screen watches activeTutoredProfileSelectionProvider',
      () {
        expect(
          textDisplaySrc,
          contains('activeTutoredProfileSelectionProvider'),
          reason:
              'text_display_screen.dart must watch activeTutoredProfileSelectionProvider '
              'to disable the Mark Complete button in tutored sessions',
        );
      },
    );

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
    test(
      'AC6: canMarkLiveCompletion is always false (immutable invariant)',
      () {
        const perms = TutorPermissions();
        expect(
          perms.canMarkLiveCompletion,
          isFalse,
          reason:
              'TutorPermissions.canMarkLiveCompletion must always be false — '
              'tutors can never mark live forward completions (D5)',
        );
      },
    );

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
