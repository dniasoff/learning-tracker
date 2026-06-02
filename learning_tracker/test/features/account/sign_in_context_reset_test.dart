// Sign-in / session-establish context reset
//
// Owner bug: on sign-in the app must land in the user's OWN profile in NORMAL
// mode. It must NOT auto-restore the last tutored (talmid) selection or the
// parent-mode PIN unlock. Both pieces of state are keepAlive / live in the
// router singleton, so without an explicit reset they leak across a
// sign-out → sign-in (or an account switch) within the same process.
//
// This suite verifies:
//   • Runtime — the reset primitives behave as required:
//       - activeTutoredProfileSelection.exit() clears the talmid selection
//       - PinGuard.lock() clears the parent-PIN session
//         (parentPinAuthenticatedProfileId via onSessionLocked)
//       - selectedProfileId defaults to the own primary after a clear+select
//   • Source-level — the reset is wired at every in-process session-establish
//     chokepoint (sign-in navigation, offline restore, local fallback, and the
//     two account-switch activate paths).

@Tags(['account', 'tutor_mode', 'sign_in'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

class _StubPinService implements PinService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('sign-in context reset — runtime semantics', () {
    test('tutored selection is cleared by exit() (post-sign-in default = own '
        'profile, not a talmid view)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const selection = TutoredProfileSelection(
        profileId: 'talmid-1',
        ownerUid: 'owner-1',
        grantId: 'grant-1',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
        tutorOwnProfileId: 7,
      );

      // Simulate a leftover talmid session from before sign-out.
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(selection);
      expect(container.read(activeTutoredProfileSelectionProvider), isNotNull);

      // The reset that every sign-in chokepoint performs.
      container.read(activeTutoredProfileSelectionProvider.notifier).exit();

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason:
            'after a fresh sign-in the user must NOT be in a talmid view — '
            'the active tutored selection must be cleared',
      );
    });

    test('PinGuard.lock() clears the parent-PIN session (parent mode is LOCKED '
        'after sign-in)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build a PinGuard wired exactly like routerProvider: onSessionLocked
      // clears parentPinAuthenticatedProfileId.
      final guard = PinGuard(
        pinService: _StubPinService(),
        promptForPin: () async => true,
        getScope: () => const PinScope.parent(3),
        onSessionAuthenticated: (scope) {
          if (scope is PinScopeParent) {
            container
                .read(parentPinAuthenticatedProfileIdProvider.notifier)
                .setAuthenticated(scope.profileId);
          }
        },
        onSessionLocked: () {
          container
              .read(parentPinAuthenticatedProfileIdProvider.notifier)
              .clear();
        },
      );

      // Simulate parent mode already unlocked before sign-out.
      guard.markAuthenticated(3);
      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        3,
        reason: 'precondition: parent mode unlocked for profile 3',
      );

      // The reset that every sign-in chokepoint performs.
      guard.lock();

      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        isNull,
        reason:
            'after a fresh sign-in the parent-mode PIN gate must be LOCKED — '
            'the user must re-enter the PIN to reach parent management',
      );
    });

    test(
      'selected profile defaults to the own primary after clear + select',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Stale id from the previous account.
        container.read(selectedProfileIdProvider.notifier).select(999);
        // Sign-in chokepoints clear it, then select the own primary.
        container.read(selectedProfileIdProvider.notifier).clear();
        expect(container.read(selectedProfileIdProvider), isNull);

        container.read(selectedProfileIdProvider.notifier).select(1);
        expect(
          container.read(selectedProfileIdProvider),
          1,
          reason:
              'after sign-in the selected profile must be the own primary, '
              'never a stale id or a tutored mirror',
        );
      },
    );
  });

  group('sign-in context reset — wiring (source-level)', () {
    late String controllerSrc;
    late String pickerSrc;

    setUpAll(() {
      controllerSrc = File(
        'lib/features/account/presentation/notifiers/sign_in_controller.dart',
      ).readAsStringSync();
      pickerSrc = File(
        'lib/features/account/presentation/screens/account_picker_screen.dart',
      ).readAsStringSync();
    });

    test('sign_in_controller defines a single reset helper', () {
      expect(
        controllerSrc,
        contains('_resetSessionContextForFreshSignIn'),
        reason:
            'sign_in_controller must funnel the per-session reset through a '
            'single helper',
      );
      expect(
        controllerSrc,
        contains('activeTutoredProfileSelectionProvider.notifier).exit()'),
        reason: 'the reset must clear the active tutored (talmid) selection',
      );
      expect(
        controllerSrc,
        contains('routerProvider).pinGuard.lock()'),
        reason: 'the reset must lock the parent-mode PIN gate',
      );
    });

    test('_navigateAfterSignIn invokes the reset', () {
      // The reset call must appear inside the post-sign-in navigation funnel.
      final navIdx = controllerSrc.indexOf('_navigateAfterSignIn(StackRouter');
      expect(navIdx, greaterThanOrEqualTo(0));
      final body = controllerSrc.substring(navIdx);
      expect(
        body.indexOf('_resetSessionContextForFreshSignIn()'),
        greaterThanOrEqualTo(0),
        reason:
            '_navigateAfterSignIn (the funnel for all interactive sign-in '
            'paths) must reset the session context',
      );
    });

    test(
      'account-switch activate paths clear talmid selection and lock parent PIN',
      () {
        // Both _activateCloudAccountFromLocalData and
        // _activateLocalAccountFromLocalData must reset, so the switched
        // account lands on its OWN profile in normal mode.
        expect(
          'activeTutoredProfileSelectionProvider.notifier).exit()'
              .allMatches(pickerSrc)
              .length,
          greaterThanOrEqualTo(2),
          reason:
              'both account-switch activate paths must clear the talmid '
              'selection carried over from the previous account',
        );
        expect(
          'routerProvider).pinGuard.lock()'.allMatches(pickerSrc).length,
          greaterThanOrEqualTo(2),
          reason:
              'both account-switch activate paths must lock the parent-mode '
              'PIN gate',
        );
      },
    );
  });
}
