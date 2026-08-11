// Unit tests for PinGuard — all onNavigation branches, session helpers,
// lock/markAuthenticated, and getScope routing (parent vs tutor).
//
// Branch map (pin_guard.dart onNavigation):
//   B1: getScope() == null                         → next(false)
//   B2: _authenticatedScope == scope (cached)      → next(true)
//   B3: no PIN set, setup flow returns true        → next(true), scope cached
//   B4: no PIN set, setup flow returns false       → next(false), no cache
//   B5: no PIN set, setup flow returns null        → next(false), no cache
//   B6: PIN set, promptForPin returns true         → next(true), scope cached
//   B7: PIN set, promptForPin returns false        → next(false), no cache
//
// Session helpers:
//   S1: lock() clears _authenticatedScope, fires onSessionLocked
//   S2: markAuthenticated(profileId) sets parent scope, fires onSessionAuthenticated
//   S3: markScopeAuthenticated(scope) sets arbitrary scope, fires onSessionAuthenticated
//
// getScope routing:
//   G1: PinScopeParent → pinService.hasProfilePin called
//   G2: PinScopeTutor  → pinService.hasTutorPin called
//   G3: independent namespaces — parent auth does not short-circuit tutor guard
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks / fakes ─────────────────────────────────────────────────────────────

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class MockPinService extends Mock implements PinService {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Stub [router.push<bool>(...)] to return [returnValue].
void _stubRouterPush(MockStackRouter router, bool? returnValue) {
  when(
    () => router.push<bool>(any<PageRouteInfo>()),
  ).thenAnswer((_) async => returnValue);
}

/// Default scope used across most tests (parent, profileId=1).
const _parentScope = PinScopeParent('1');
const _tutorScope = PinScopeTutor('1');

/// Creates a fresh resolver whose next/next(bool) calls are silenced.
MockNavigationResolver _resolver() {
  final r = MockNavigationResolver();
  when(() => r.next()).thenReturn(null);
  when(() => r.next(any<bool>())).thenReturn(null);
  return r;
}

void main() {
  late MockNavigationResolver resolver;
  late MockStackRouter router;
  late MockPinService pinService;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    resolver = _resolver();
    router = MockStackRouter();
    pinService = MockPinService();
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  // ── B1: getScope returns null ────────────────────────────────────────────────

  group('B1 — getScope returns null', () {
    test('calls next(false) and does not touch router', () async {
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true, // should never be reached
        getScope: () => null,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => resolver.next(true));
      verifyNever(() => router.push<bool>(any<PageRouteInfo>()));
    });
  });

  // ── B2: scope already authenticated this session ─────────────────────────────

  group('B2 — scope already cached in session', () {
    test('parent scope: next(true) without calling promptForPin', () async {
      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _parentScope,
      );

      // Pre-authenticate the scope.
      guard.markScopeAuthenticated(_parentScope);

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
      expect(
        promptCalls,
        0,
        reason: 'promptForPin must not be called when cached',
      );
    });

    test('tutor scope: next(true) without calling promptForPin', () async {
      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _tutorScope,
      );

      guard.markScopeAuthenticated(_tutorScope);

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
      expect(promptCalls, 0);
    });
  });

  // ── B3: no PIN set, setup flow returns true ───────────────────────────────────

  group('B3 — no PIN set, setup returns true', () {
    test('pushes setup route, caches scope, calls next(true)', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => false);
      _stubRouterPush(router, true);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false, // should not be reached
        getScope: () => _parentScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verify(() => router.push<bool>(any<PageRouteInfo>())).called(1);
      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
      expect(authenticated, [_parentScope]);
    });

    test(
      'AUD-core-navigation-01: pushes exactly the route returned by the '
      'injected pinSetupRoute builder, not a route the guard builds itself',
      () async {
        // Regression for the app→core→app import cycle: PinGuard used to
        // hardcode `const PinFlowSetupRoute()` internally (importing the
        // app-layer route class directly). Prove the push route is now
        // fully caller-controlled by injecting a distinctive marker route
        // that the guard could not possibly have constructed on its own.
        when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => false);
        _stubRouterPush(router, true);

        final guard = PinGuard(
          pinSetupRoute: () =>
              const PageRouteInfo('AUD_CORE_NAV_01_MARKER_ROUTE'),
          pinService: pinService,
          promptForPin: () async => false,
          getScope: () => _parentScope,
        );

        await guard.onNavigation(resolver, router);

        verify(
          () => router.push<bool>(
            any<PageRouteInfo>(
              that: isA<PageRouteInfo>().having(
                (r) => r.routeName,
                'routeName',
                'AUD_CORE_NAV_01_MARKER_ROUTE',
              ),
            ),
          ),
        ).called(1);
      },
    );
  });

  // ── B4: no PIN set, setup flow returns false ──────────────────────────────────

  group('B4 — no PIN set, setup returns false', () {
    test(
      'pushes setup route, does NOT cache scope, calls next(false)',
      () async {
        when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => false);
        _stubRouterPush(router, false);

        final authenticated = <PinScope>[];
        final guard = PinGuard(
          pinSetupRoute: () => _FakePageRouteInfo(),
          pinService: pinService,
          promptForPin: () async => false,
          getScope: () => _parentScope,
          onSessionAuthenticated: authenticated.add,
        );

        await guard.onNavigation(resolver, router);

        verify(() => router.push<bool>(any<PageRouteInfo>())).called(1);
        verify(() => resolver.next(false)).called(1);
        verifyNever(() => resolver.next(true));
        expect(authenticated, isEmpty);
      },
    );
  });

  // ── B5: no PIN set, setup flow returns null (dismissed) ─────────────────────

  group('B5 — no PIN set, setup returns null', () {
    test('treats null as false — next(false), scope not cached', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => false);
      _stubRouterPush(router, null);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => _parentScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verify(() => router.push<bool>(any<PageRouteInfo>())).called(1);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
      expect(authenticated, isEmpty);
    });
  });

  // ── B6: PIN set, promptForPin returns true ────────────────────────────────────

  group('B6 — PIN set, correct PIN entered', () {
    test('parent scope: caches scope, calls next(true)', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _parentScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verifyNever(() => router.push<bool>(any<PageRouteInfo>()));
      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
      expect(authenticated, [_parentScope]);
    });

    test('tutor scope: caches scope, calls next(true)', () async {
      when(() => pinService.hasTutorPin('1')).thenAnswer((_) async => true);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _tutorScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
      expect(authenticated, [_tutorScope]);
    });

    test('subsequent navigation skips prompt (cache hit)', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _parentScope,
      );

      // First navigation: PIN prompt shown.
      await guard.onNavigation(resolver, router);
      expect(promptCalls, 1);

      // Second navigation: must use cache — no prompt.
      final resolver2 = _resolver();
      await guard.onNavigation(resolver2, router);

      expect(promptCalls, 1, reason: 'second navigation must use cache');
      verify(() => resolver2.next(true)).called(1);
    });
  });

  // ── B7: PIN set, promptForPin returns false (wrong / cancelled) ───────────────

  group('B7 — PIN set, wrong/cancelled PIN', () {
    test('parent scope: next(false), scope NOT cached', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => _parentScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
      verifyNever(() => router.push<bool>(any<PageRouteInfo>()));
      expect(authenticated, isEmpty);
    });

    test('tutor scope: next(false), scope NOT cached', () async {
      when(() => pinService.hasTutorPin('1')).thenAnswer((_) async => true);

      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => _tutorScope,
        onSessionAuthenticated: authenticated.add,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
      expect(authenticated, isEmpty);
    });
  });

  // ── S1: lock() ───────────────────────────────────────────────────────────────

  group('S1 — lock()', () {
    test('clears authenticated scope so next navigation re-prompts', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _parentScope,
      );

      // Authenticate.
      await guard.onNavigation(resolver, router);
      expect(promptCalls, 1);

      // Lock.
      guard.lock();

      // Next navigation must show the prompt again.
      final resolver2 = _resolver();
      await guard.onNavigation(resolver2, router);

      expect(promptCalls, 2, reason: 'lock() must clear the session cache');
    });

    test('fires onSessionLocked callback', () async {
      var lockCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _parentScope,
        onSessionLocked: () => lockCalls++,
      );

      guard.lock();

      expect(lockCalls, 1);
    });

    test(
      'does not throw when no onSessionLocked callback is registered',
      () async {
        final guard = PinGuard(
          pinSetupRoute: () => _FakePageRouteInfo(),
          pinService: pinService,
          promptForPin: () async => true,
          getScope: () => _parentScope,
        );

        expect(() => guard.lock(), returnsNormally);
      },
    );
  });

  // ── S2: markAuthenticated ────────────────────────────────────────────────────

  group('S2 — markAuthenticated(profileId)', () {
    test('sets parent scope so next navigation skips prompt', () async {
      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _parentScope,
      );

      guard.markAuthenticated('1'); // profileId=1 matches _parentScope

      await guard.onNavigation(resolver, router);

      expect(promptCalls, 0, reason: 'markAuthenticated must prime the cache');
      verify(() => resolver.next(true)).called(1);
    });

    test('fires onSessionAuthenticated with parent scope', () async {
      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _parentScope,
        onSessionAuthenticated: authenticated.add,
      );

      guard.markAuthenticated('1');

      expect(authenticated, [const PinScopeParent('1')]);
    });
  });

  // ── S3: markScopeAuthenticated ───────────────────────────────────────────────

  group('S3 — markScopeAuthenticated(scope)', () {
    test('sets tutor scope so next navigation skips prompt', () async {
      var promptCalls = 0;
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async {
          promptCalls++;
          return true;
        },
        getScope: () => _tutorScope,
      );

      guard.markScopeAuthenticated(_tutorScope);

      await guard.onNavigation(resolver, router);

      expect(promptCalls, 0);
      verify(() => resolver.next(true)).called(1);
    });

    test('fires onSessionAuthenticated with the given scope', () async {
      final authenticated = <PinScope>[];
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _tutorScope,
        onSessionAuthenticated: authenticated.add,
      );

      guard.markScopeAuthenticated(_tutorScope);

      expect(authenticated, [_tutorScope]);
    });
  });

  // ── G1/G2: getScope routing — hasProfilePin vs hasTutorPin ───────────────────

  group('G1 — PinScopeParent routes to hasProfilePin', () {
    test('calls pinService.hasProfilePin, not hasTutorPin', () async {
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => _parentScope,
      );

      await guard.onNavigation(resolver, router);

      verify(() => pinService.hasProfilePin('1')).called(1);
      verifyNever(() => pinService.hasTutorPin(any<String>()));
    });
  });

  group('G2 — PinScopeTutor routes to hasTutorPin', () {
    test('calls pinService.hasTutorPin, not hasProfilePin', () async {
      when(() => pinService.hasTutorPin('1')).thenAnswer((_) async => true);

      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => false,
        getScope: () => _tutorScope,
      );

      await guard.onNavigation(resolver, router);

      verify(() => pinService.hasTutorPin('1')).called(1);
      verifyNever(() => pinService.hasProfilePin(any<String>()));
    });
  });

  // ── G3: scope independence — parent auth does not grant tutor ────────────────

  group('G3 — scope independence', () {
    test(
      'parent-scoped session does not short-circuit a tutor-scoped guard',
      () async {
        when(() => pinService.hasTutorPin('1')).thenAnswer((_) async => true);

        var promptCalls = 0;
        final guard = PinGuard(
          pinSetupRoute: () => _FakePageRouteInfo(),
          pinService: pinService,
          promptForPin: () async {
            promptCalls++;
            return true;
          },
          getScope: () => _tutorScope,
        );

        // Mark parent scope as authenticated — must NOT satisfy tutor check.
        guard.markAuthenticated('1'); // sets PinScopeParent('1')

        await guard.onNavigation(resolver, router);

        // The tutor-scoped guard must still prompt.
        expect(
          promptCalls,
          1,
          reason: 'parent auth must not grant tutor access',
        );
        verify(() => resolver.next(true)).called(1);
      },
    );

    test(
      'tutor-scoped session does not short-circuit a parent-scoped guard',
      () async {
        when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);

        var promptCalls = 0;
        final guard = PinGuard(
          pinSetupRoute: () => _FakePageRouteInfo(),
          pinService: pinService,
          promptForPin: () async {
            promptCalls++;
            return true;
          },
          getScope: () => _parentScope,
        );

        // Mark tutor scope authenticated — must NOT satisfy parent check.
        guard.markScopeAuthenticated(_tutorScope);

        await guard.onNavigation(resolver, router);

        expect(
          promptCalls,
          1,
          reason: 'tutor auth must not grant parent access',
        );
        verify(() => resolver.next(true)).called(1);
      },
    );
  });

  // ── Dead-end / lockout audit ─────────────────────────────────────────────────
  //
  // Every path must terminate with next() or next(bool) — never leave the user
  // stranded. Each branch above already asserts exactly one terminal call.
  // Additional edge case: scope changes between navigations.

  group('edge case — scope identity changes between navigations', () {
    test(
      'different profileId is treated as a different scope (cache miss)',
      () async {
        when(
          () => pinService.hasProfilePin(any<String>()),
        ).thenAnswer((_) async => true);

        var promptCalls = 0;
        var currentProfileId = '1';
        final guard = PinGuard(
          pinSetupRoute: () => _FakePageRouteInfo(),
          pinService: pinService,
          promptForPin: () async {
            promptCalls++;
            return true;
          },
          getScope: () => PinScopeParent(currentProfileId),
        );

        // Nav 1: profileId=1 — prompt shown, cached.
        await guard.onNavigation(resolver, router);
        expect(promptCalls, 1);

        // Switch profile and navigate again — different scope, must prompt again.
        currentProfileId = '2';
        final resolver2 = _resolver();

        await guard.onNavigation(resolver2, router);

        expect(
          promptCalls,
          2,
          reason: 'scope change (profileId) must invalidate cache',
        );
        verify(() => resolver2.next(true)).called(1);
      },
    );
  });

  // ── Fail-safe: unexpected throw → fail CLOSED (security gate), no hang ─────
  //
  // promptForPin (which internally verifies the PIN) can throw — e.g.
  // PinLockoutException after too many attempts, or a secure-storage error;
  // hasProfilePin/hasTutorPin read secure storage and can throw too. The guard
  // wraps onNavigation in a try/catch that fails CLOSED (next(false)) so the
  // user is cleanly denied rather than left on a hung, unresolved navigation.
  group('unexpected throw (fail-closed, no dead-end)', () {
    test('promptForPin throwing → next(false), no throw, no hang', () async {
      when(() => resolver.isResolved).thenReturn(false);
      when(() => pinService.hasProfilePin('1')).thenAnswer((_) async => true);
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => throw Exception('PIN verify boom'),
        getScope: () => _parentScope,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
    });

    test('hasPin throwing → next(false), fails closed', () async {
      when(() => resolver.isResolved).thenReturn(false);
      when(
        () => pinService.hasProfilePin('1'),
      ).thenThrow(Exception('secure storage boom'));
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: pinService,
        promptForPin: () async => true,
        getScope: () => _parentScope,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
    });
  });
}
