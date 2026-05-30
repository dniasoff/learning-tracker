// F3 — account-switch reset for active tutored selection
//
// Verifies that the account-switch reset behaviour is preserved after the
// auth-watch was moved from active_tutored_profile_provider.dart into
// AppShell's ref.listen. The mechanism is now:
//
//   AppShellScreen.build() calls:
//     ref.listen(authStateProvider.select(uid), (prev, next) {
//       if (prev != next) activeTutoredProfileSelectionProvider.exit();
//     })
//
// AC1 — entering a selection sets non-null state
// AC2 — exit() clears the selection (and resolvedTutoredLocalProfileId)
// AC3 — the auth-watch import is GONE from active_tutored_profile_provider.dart
//        (the root cause of the 200 test failures)
// AC4 — app_shell.dart contains the replacement ref.listen on authStateProvider

@Tags(['f3', 'tutor_mode', 'account_switch'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

void main() {
  group('F3 — account-switch reset (auth-watch migration)', () {
    late String providerSrc;
    late String shellSrc;

    setUpAll(() {
      providerSrc = File(
        'lib/features/tutoring/presentation/providers/active_tutored_profile_provider.dart',
      ).readAsStringSync();

      shellSrc = File('lib/app/router/app_shell.dart').readAsStringSync();
    });

    // ── AC3 / AC4 — structural assertions (source-level, no Firebase) ─────────

    test(
      'AC3: authStateProvider import removed from active_tutored_profile_provider',
      () {
        expect(
          providerSrc,
          isNot(contains('auth_state_provider')),
          reason:
              'active_tutored_profile_provider.dart must NOT import auth_state_provider — '
              'that import materialised FirebaseAuth.instance in widget tests and '
              'caused ~200 test failures (F3 root cause)',
        );
      },
    );

    test('AC3: authStateProvider ref.watch removed from build()', () {
      expect(
        providerSrc,
        isNot(contains('ref.watch(authStateProvider')),
        reason:
            'ref.watch(authStateProvider…) must not appear in the provider build() '
            'methods — the reset is now handled by AppShell ref.listen',
      );
    });

    test('AC4: app_shell.dart has ref.listen on authStateProvider', () {
      expect(
        shellSrc,
        contains('ref.listen'),
        reason:
            'AppShellScreen.build() must contain ref.listen to handle account-switch reset',
      );
      expect(
        shellSrc,
        contains('authStateProvider'),
        reason:
            'AppShellScreen.build() must listen on authStateProvider for uid changes',
      );
      expect(
        shellSrc,
        contains('activeTutoredProfileSelectionProvider.notifier'),
        reason:
            'AppShell ref.listen must reference activeTutoredProfileSelectionProvider.notifier',
      );
      expect(
        shellSrc,
        contains('.exit()'),
        reason: 'AppShell ref.listen must call .exit() on account uid change',
      );
    });

    // ── AC1 / AC2 — runtime state assertions (no Firebase needed) ─────────────

    test('AC1: entering a TutoredProfileSelection sets non-null state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const selection = TutoredProfileSelection(
        profileId: 'profile-123',
        ownerUid: 'owner-uid-1',
        grantId: 'grant-abc',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
        tutorOwnProfileId: 42,
      );

      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(selection);

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        same(selection),
        reason: 'enter() must set the selection as the provider state',
      );
    });

    test('AC2: exit() clears the selection and resolved local profile id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const selection = TutoredProfileSelection(
        profileId: 'profile-456',
        ownerUid: 'owner-uid-2',
        grantId: 'grant-xyz',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
      );

      final selectionNotifier = container.read(
        activeTutoredProfileSelectionProvider.notifier,
      );
      final resolvedNotifier = container.read(
        resolvedTutoredLocalProfileIdProvider.notifier,
      );

      // Enter a tutored session and set a resolved mirror id.
      selectionNotifier.enter(selection);
      resolvedNotifier.resolve(99);

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNotNull,
        reason: 'selection must be non-null after enter()',
      );
      expect(
        container.read(resolvedTutoredLocalProfileIdProvider),
        99,
        reason: 'resolved id must be set after resolve()',
      );

      // exit() simulates what AppShell's ref.listen calls on uid change.
      selectionNotifier.exit();

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason: 'exit() must clear the selection (account-switch reset)',
      );
      expect(
        container.read(resolvedTutoredLocalProfileIdProvider),
        isNull,
        reason: 'exit() must also clear the resolved mirror id',
      );
    });

    test('AC2: initial state is null (no tutored session on fresh boot)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason: 'initial state must be null — no tutored context on fresh boot',
      );
      expect(
        container.read(resolvedTutoredLocalProfileIdProvider),
        isNull,
        reason: 'initial resolved id must be null on fresh boot',
      );
    });
  });
}
