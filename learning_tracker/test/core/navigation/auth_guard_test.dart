// Unit tests for AuthGuard — every branch of onNavigation.
//
// Decision tree (lib/app/router/guards/auth_guard.dart):
//
//   Branch 1: onboarding_complete == true  → resolver.next()         (pass-through)
//   Branch 2: onboarding_complete == false, intro_seen == false
//             → router.replace(AppIntroRoute) + resolver.next(false)  (intro redirect)
//   Branch 3: onboarding_complete == false, intro_seen == true, no registry accounts
//             → router.replace(SignInRoute) + resolver.next(false)    (sign-in redirect)
//   Branch 4: onboarding_complete == false, intro_seen == true, accounts exist
//             → router.replace(AccountPickerRoute) + resolver.next(false) (picker redirect)
//
// Every branch MUST end in either resolver.next() or resolver.next(false)
// — never a dead-end/lockout.
//
// NOTE on the "accounts exist" branch:
//   AuthGuard creates a DeviceRegistryDatabase internally via driftDatabase()
//   which opens `$appDocDir/device_registry.sqlite`.  We pre-seed that file
//   using a NativeDatabase directly before running the guard so that the guard
//   sees accounts on its first (and only) open.  The path_provider method
//   channel is mocked to `/tmp/flutter_test_auth_guard` to give each test a
//   clean, isolated directory.
library;

import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks / fakes ────────────────────────────────────────────────────────────

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

/// Fake PageRouteInfo required by mocktail for any<PageRouteInfo>() matchers.
class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Absolute path used by the mocked `getApplicationDocumentsDirectory`.
/// Must be a path that actually exists so that `NativeDatabase` can create the
/// `.sqlite` file next to it when we pre-seed the registry.
const _kTestAppDocDir = '/tmp/flutter_test_auth_guard';

/// Full path where `driftDatabase(name: 'device_registry')` will write its
/// file, given the path_provider mock below.
const _kRegistryPath = '$_kTestAppDocDir/device_registry.sqlite';

/// Install a method-channel mock for `path_provider` that routes all document-
/// / support- / temporary-directory lookups to [_kTestAppDocDir].
///
/// Must be called inside `setUpAll` (after `TestWidgetsFlutterBinding.ensureInitialized()`).
void _installPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async {
          switch (call.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
              return _kTestAppDocDir;
            default:
              return null;
          }
        },
      );
}

/// Seed one account into the registry file at [_kRegistryPath].
///
/// Opens the file with [NativeDatabase] directly (no background isolate), so
/// the seed completes synchronously and the file is flushed before the guard
/// opens it through `driftDatabase`.
Future<void> _seedRegistryAccount() async {
  final dir = Directory(_kTestAppDocDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final registry = DeviceRegistryDatabase(NativeDatabase(File(_kRegistryPath)));
  try {
    await registry
        .into(registry.deviceAccounts)
        .insert(
          DeviceAccountsCompanion.insert(
            accountId: 'test-account-1',
            email: 'alice@example.com',
            displayName: 'Alice',
            tier: 'localBorn',
            createdAt: DateTime.utc(2025),
            lastUsedAt: DateTime.utc(2025),
            dbFileName: 'user_alice.db',
          ),
        );
  } finally {
    await registry.close();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthGuard guard;
  late MockNavigationResolver resolver;
  late MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    _installPathProviderMock();
    // Ensure the temp directory exists for the whole suite.
    Directory(_kTestAppDocDir).createSync(recursive: true);
  });

  setUp(() {
    guard = AuthGuard();
    resolver = MockNavigationResolver();
    router = MockStackRouter();

    when(() => resolver.next()).thenReturn(null);
    when(() => resolver.next(any<bool>())).thenReturn(null);
    when(() => resolver.isResolved).thenReturn(false);
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    // Remove the pre-seeded registry file between tests so each test starts
    // clean.  The guard creates its own connection on each call, so deleting
    // the file here is safe.
    final f = File(_kRegistryPath);
    if (f.existsSync()) f.deleteSync();
  });

  // ── Branch 1: onboarding already complete ────────────────────────────────

  group('Branch 1 — onboarding complete', () {
    test('calls resolver.next() — user passes through', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });

    test('never reaches a dead-end — resolver is always resolved', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      // No exception thrown → guard always resolved.
      await expectLater(guard.onNavigation(resolver, router), completes);
      verify(() => resolver.next()).called(1);
    });
  });

  // ── Branch 2: intro slides not yet seen ──────────────────────────────────

  group('Branch 2 — intro not seen', () {
    test('replaces with AppIntroRoute', () async {
      SharedPreferences.setMockInitialValues({}); // neither flag set

      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured;
      expect(captured.single, isA<AppIntroRoute>());
    });

    test('calls resolver.next(false) — blocks original navigation', () async {
      SharedPreferences.setMockInitialValues({});

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test('same result when intro_seen is explicitly false '
        '(vs completely absent)', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': false});

      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured;
      expect(captured.single, isA<AppIntroRoute>());
      verify(() => resolver.next(false)).called(1);
    });
  });

  // ── Branch 3: intro seen, no accounts on device → SignInRoute ────────────

  group('Branch 3 — intro seen, no accounts on device', () {
    setUp(() {
      // Ensure the registry file is absent so getAllAccounts() → [].
      final f = File(_kRegistryPath);
      if (f.existsSync()) f.deleteSync();
    });

    test('replaces with SignInRoute', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured;
      expect(captured.single, isA<SignInRoute>());
    });

    test('calls resolver.next(false) — blocks original navigation', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test('never a dead-end — resolver always resolved', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await expectLater(guard.onNavigation(resolver, router), completes);

      // For this branch the guard calls next(false) exactly once.
      verify(() => resolver.next(false)).called(1);
    });
  });

  // ── Branch 4: intro seen, accounts exist → AccountPickerRoute ────────────

  group('Branch 4 — intro seen, accounts on device', () {
    setUp(() async {
      await _seedRegistryAccount();
    });

    test('replaces with AccountPickerRoute', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured;
      expect(captured.single, isA<AccountPickerRoute>());
    });

    test('calls resolver.next(false) — blocks original navigation', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test('never a dead-end — resolver always resolved', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await expectLater(guard.onNavigation(resolver, router), completes);

      // For this branch the guard calls next(false) exactly once.
      verify(() => resolver.next(false)).called(1);
    });
  });

  // ── Cross-branch: ALWAYS resolves ────────────────────────────────────────
  //
  // Rather than counting both variants in a single test (mocktail throws if
  // you verify a call that was never made), each scenario asserts the correct
  // single resolver call for its branch.

  group('Invariant — guard always resolves, never a dead-end', () {
    test('onboarded → resolver.next() called', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      await expectLater(guard.onNavigation(resolver, router), completes);
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
    });

    test('intro not seen → resolver.next(false) called', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(guard.onNavigation(resolver, router), completes);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test('intro seen, no accounts → resolver.next(false) called', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});
      await expectLater(guard.onNavigation(resolver, router), completes);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test('intro seen, with account → resolver.next(false) called', () async {
      await _seedRegistryAccount();
      SharedPreferences.setMockInitialValues({'intro_seen': true});
      await expectLater(guard.onNavigation(resolver, router), completes);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });
  });

  // ── Redirect destination contracts ────────────────────────────────────────

  group('Redirect destinations are valid, navigable routes', () {
    test('AppIntroRoute is the intro-not-seen destination', () async {
      SharedPreferences.setMockInitialValues({});
      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured.single;
      // Must be AppIntroRoute (not OnboardingRoute, not SignInRoute).
      expect(captured, isA<AppIntroRoute>());
      expect(captured, isNot(isA<SignInRoute>()));
      expect(captured, isNot(isA<AccountPickerRoute>()));
    });

    test('SignInRoute is the no-accounts destination', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});
      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured.single;
      expect(captured, isA<SignInRoute>());
    });

    test('AccountPickerRoute is the has-accounts destination', () async {
      await _seedRegistryAccount();
      SharedPreferences.setMockInitialValues({'intro_seen': true});
      await guard.onNavigation(resolver, router);

      final captured = verify(
        () => router.replace(captureAny<PageRouteInfo>()),
      ).captured.single;
      expect(captured, isA<AccountPickerRoute>());
    });
  });

  // ── Fail-safe: unexpected error never hangs the resolver ──────────────────
  //
  // The first-launch gate runs on every guarded navigation. If the
  // device_registry DB is corrupt/unreadable (or SharedPreferences fails),
  // getAllAccounts() throws — previously that escaped onNavigation and left
  // AutoRoute's resolver completer un-completed forever (a navigation hang).
  // The guard now wraps the body in a try/catch that fails SAFE: it routes to
  // the always-reachable SignInRoute and resolves, rather than hanging.

  group('Fail-safe — corrupt registry never dead-ends', () {
    test(
      'unreadable device_registry → SignInRoute + next(false), no hang',
      () async {
        SharedPreferences.setMockInitialValues({'intro_seen': true});
        // Write a non-sqlite file so driftDatabase open/query throws.
        final dir = Directory(_kTestAppDocDir);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File(_kRegistryPath).writeAsStringSync('this is not a sqlite database');

        await expectLater(guard.onNavigation(resolver, router), completes);

        final captured = verify(
          () => router.replace(captureAny<PageRouteInfo>()),
        ).captured.last;
        expect(captured, isA<SignInRoute>());
        verify(() => resolver.next(false)).called(1);
        verifyNever(() => resolver.next());
      },
    );
  });
}
