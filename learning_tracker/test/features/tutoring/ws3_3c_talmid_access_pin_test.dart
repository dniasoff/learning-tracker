// WS3.3c — Talmid access + PIN (DEC-13-tutor, DEC-24) [gates 3d]
//
// Verifies that:
//   AC1 — tutored_children_section.dart wires onTap (no longer null) and
//          references TutorPinEntryGate.
//   AC2 — router_provider.dart resolves PinScope.tutor() when an active
//          TutoredProfileSelection is set (by checking activeTutoredProfileSelectionProvider).
//   AC3 — PinScope.tutor() already exists in pin_scope.dart (pre-existing).
//   AC4 — ActiveTutoredProfileSelectionProvider exists and can enter/exit.
//   AC5 — TutorPinEntryGate is referenced (instantiated) in the talmid row.

@Tags(['ws3', 'ws3_3c', 'tutor_mode'])
library;

import 'dart:io';

import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:test/test.dart';

void main() {
  group('WS3.3c — Talmid access + PIN (DEC-13-tutor, DEC-24)', () {
    late String sectionSrc;
    late String routerProviderSrc;
    late String pinScopeSrc;
    late String activeTutoredProviderSrc;

    setUpAll(() {
      sectionSrc = File(
        'lib/features/profiles/presentation/widgets/tutored_children_section.dart',
      ).readAsStringSync();

      routerProviderSrc = File(
        'lib/app/router/router_provider.dart',
      ).readAsStringSync();

      pinScopeSrc = File(
        'lib/core/navigation/pin_scope.dart',
      ).readAsStringSync();

      activeTutoredProviderSrc = File(
        'lib/features/tutoring/presentation/providers/active_tutored_profile_provider.dart',
      ).readAsStringSync();
    });

    // ── AC1: TutorPinEntryGate wired into talmid row ─────────────────────────

    test(
      'AC1: TutorPinEntryGate is referenced in tutored_children_section',
      () {
        expect(
          sectionSrc,
          contains('TutorPinEntryGate'),
          reason:
              'TutorPinEntryGate must be instantiated in the talmid row '
              '(WS3.3c — DEC-13-tutor: PIN required on every talmid view)',
        );
      },
    );

    test('AC1: Talmid row onTap is non-null (_enterTalmidView)', () {
      expect(
        sectionSrc,
        contains('_enterTalmidView'),
        reason:
            'Talmid row must have a non-null onTap wired to _enterTalmidView',
      );
    });

    // ── AC2: router_provider resolves PinScope from active selection ──────────

    test('AC2: router_provider checks activeTutoredProfileSelectionProvider', () {
      expect(
        routerProviderSrc,
        contains('activeTutoredProfileSelectionProvider'),
        reason:
            'router_provider.dart must check activeTutoredProfileSelectionProvider '
            'to resolve PinScope.tutor() when a tutored session is active',
      );
    });

    test(
      'AC2: router_provider resolves PinScope.tutor() for tutored context',
      () {
        expect(
          routerProviderSrc,
          contains('PinScope.tutor('),
          reason:
              'router_provider.dart must resolve PinScope.tutor(profileId) '
              'when a TutoredProfileSelection is active',
        );
      },
    );

    test(
      'AC2: router_provider falls back to PinScope.parent() for own profile',
      () {
        expect(
          routerProviderSrc,
          contains('PinScope.parent('),
          reason:
              'router_provider.dart must fall back to PinScope.parent(profileId) '
              'for own-profile routes',
        );
      },
    );

    // ── AC3: PinScope.tutor() exists (pre-existing sealed variant) ────────────

    test('AC3: PinScope.tutor() factory exists in pin_scope.dart', () {
      expect(
        pinScopeSrc,
        contains('PinScope.tutor('),
        reason:
            'PinScope.tutor(profileId) must exist in pin_scope.dart '
            '(confirmed pre-existing — verified WS3.3c baseline)',
      );
    });

    test('AC3: PinScopeTutor sealed variant exists', () {
      expect(
        pinScopeSrc,
        contains('PinScopeTutor'),
        reason: 'PinScopeTutor sealed class must exist in pin_scope.dart',
      );
    });

    // ── AC4: ActiveTutoredProfileSelectionProvider enter/exit ─────────────────

    test('AC4: ActiveTutoredProfileSelectionProvider has enter() method', () {
      expect(
        activeTutoredProviderSrc,
        contains('void enter('),
        reason:
            'ActiveTutoredProfileSelectionProvider must expose an enter() '
            'method to set the active tutored context',
      );
    });

    test('AC4: ActiveTutoredProfileSelectionProvider has exit() method', () {
      expect(
        activeTutoredProviderSrc,
        contains('void exit()'),
        reason:
            'ActiveTutoredProfileSelectionProvider must expose an exit() '
            'method to clear the tutored context',
      );
    });

    // ── AC4: Domain model round-trip ─────────────────────────────────────────

    test('AC4d: TutoredProfileSelection carries correct fields', () {
      const perms = TutorPermissions(canBulkPriorCompletion: true);
      const selection = TutoredProfileSelection(
        profileId: 'child-profile-123',
        ownerUid: 'parent-uid-456',
        grantId: 'grant-789',
        permissions: perms,
      );
      expect(selection.profileId, 'child-profile-123');
      expect(selection.ownerUid, 'parent-uid-456');
      expect(selection.grantId, 'grant-789');
      expect(selection.permissions.canBulkPriorCompletion, isTrue);
    });

    test('AC4e: PinScope.tutor resolves correct profileId', () {
      const scope = PinScope.tutor('42');
      expect(scope, isA<PinScopeTutor>());
      expect(scope.profileId, '42');
    });

    test(
      'AC4f: PinScope.parent and PinScope.tutor with same ID are not equal',
      () {
        const parent = PinScope.parent('1');
        const tutor = PinScope.tutor('1');
        expect(parent, isNot(equals(tutor)));
      },
    );

    // ── BUG-1 UX follow-up: switcher sheet must not linger after PIN success ──
    //
    // Root cause: the talmid row pushed the TutorPinEntryGate ON TOP of the
    // still-mounted profile-switcher modal sheet. On PIN success it popped only
    // the gate and then called router.replaceAll([AppShellRoute]); replaceAll
    // rebuilds auto_route's MANAGED page stack but does NOT clear the
    // imperatively-pushed modal sheet, so the sheet lingered on top of the
    // talmid dashboard. The fix explicitly dismisses the sheet (via the global
    // root navigator key) immediately before each successful navigation.

    test('BUG-1: entry navigation dismisses the lingering switcher sheet', () {
      expect(
        sectionSrc,
        contains('dismissSwitcherSheet'),
        reason:
            'On successful talmid entry the profile-switcher modal sheet must '
            'be explicitly dismissed (replaceAll does not clear it), so the '
            'tutor lands cleanly on the talmid dashboard with no leftover '
            'sheet.',
      );
    });

    test('BUG-1: sheet dismissal uses the stable root navigator key', () {
      // The widget context dies when the sheet pops, so the dismissal must go
      // through the global navigatorKey (root navigator), not the dying
      // widget context.
      expect(
        sectionSrc,
        contains('navigatorKey.currentState'),
        reason:
            'Sheet dismissal must use navigatorKey.currentState so it survives '
            'the row widget unmounting when the sheet is popped.',
      );
    });

    test('BUG-1: success path navigates via the captured router, not '
        'context.router', () {
      // After the sheet is popped the widget is unmounted, so context.router
      // is no longer usable. The fix captures the AppRouter via
      // ref.read(routerProvider) before popping and replaces the stack on it.
      expect(
        sectionSrc,
        contains('final router = ref.read(routerProvider)'),
        reason:
            'The post-pull navigation must use a captured AppRouter instance '
            'that survives the widget unmounting, not context.router.',
      );
      expect(
        sectionSrc,
        contains('router.replaceAll([const AppShellRoute()])'),
        reason: 'Talmid entry must replace the stack on the captured router.',
      );
    });
  });
}
