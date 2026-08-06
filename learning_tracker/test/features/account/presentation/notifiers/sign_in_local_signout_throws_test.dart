// Regression tests for SI-LOCAL-01:
// signOut() in the local-born sign-in path can throw
// PlatformException(clearCredentialStateAsync…) on emulators / devices
// without Google Play Services. Both code paths that call signOut() after a
// successful local-born credential verify must survive a throwing signOut()
// WITHOUT surfacing a sign-in error to the user.
//
// Paths under test:
//   A) _tryLocalFallbackSignIn  (line 245 in sign_in_controller.dart)
//   B) signInWithEmail — local registry path  (line 699)
//
// Fix: both calls are now wrapped in their own try/catch that logs a warning
// and continues (mirrors the analogous fix in signup_screen.dart for
// _signUpLocal, committed in iter2).
//
// Red → Green:
//   BEFORE the fix: signOut() exception propagated to the outer `catch (e)`
//   in signInWithEmail, which called _mapAuthErrorFromException and surfaced
//   authErrSignInGeneric ("Sign-in failed") even though auth was successful.
//   The test was RED (result was false / state was SignInError).
//   AFTER the fix: signOut() is swallowed, result is true, state is Idle.
import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_repositories.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MockPinService extends Mock implements PinService {}

/// Minimal no-op router implementation that satisfies _resetSessionContextForFreshSignIn.
/// Only pinGuard.lock() and restoreGuard.resetForNewSession() are called there.
class _StubAppRouter extends AppRouter {
  _StubAppRouter()
    : super(
        authGuard: _StubAuthGuard(),
        restoreGuard: RestoreGuard(
          getDatabase: () => throw StateError('restoreGuard db not needed'),
          hasCloudAccount: () => false,
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
        ),
        profileGuard: _StubProfileGuard(),
        childModeGuard: _StubChildModeGuard(),
        pinGuard: PinGuard(
          pinService: _MockPinService(),
          promptForPin: () async => false,
          getScope: () => null,
          pinSetupRoute: () => const PinFlowSetupRoute(),
          onSessionAuthenticated: (_) {},
          onSessionLocked: () {},
        ),
      );
}

class _StubAuthGuard extends AutoRouteGuard {
  @override
  Future<void> onNavigation(NavigationResolver r, StackRouter s) async =>
      r.next();
}

class _StubProfileGuard extends ProfileGuard {
  _StubProfileGuard()
    : super(
        getDatabase: () => throw StateError('not needed'),
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_, {String? ulid}) {},
        getAccountId: () => 1,
        isTutoredSession: () => false,
        profilePickerRoute: () => const ProfilePickerRoute(),
      );
}

class _StubChildModeGuard extends ChildModeGuard {
  _StubChildModeGuard()
    : super(
        getDatabase: () => throw StateError('not needed'),
        getSelectedProfileId: () => null,
        getActiveProfileId: () => null,
        isTutoredSession: () => false,
      );
}

/// Minimal StackRouter stub that handles replaceAll (called by the
/// successful sign-in path). Other methods still throw.
class _StubRouter implements StackRouter {
  @override
  Future<void> replaceAll(
    List<PageRouteInfo<dynamic>> routes, {
    OnNavigationFailure? onFailure,
    bool updateExistingRoutes = true,
  }) async {
    // No-op: navigation side-effects are out of scope for this unit test.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'StubRouter received an unexpected call: ${invocation.memberName}',
  );
}

/// Creates a UserDatabase backed by the given connection (defaults to
/// in-memory) and seeds a local-born account with [email] / [password].
/// Returns the database so callers can add it to provider overrides.
Future<UserDatabase> _seedLocalAccount({
  required String email,
  required String password,
  required String displayName,
}) async {
  final db = UserDatabase(NativeDatabase.memory());
  final service = LocalAuthService(dao: db.userProfileDao);
  await service.signUp(
    email: email,
    password: password,
    displayName: displayName,
  );
  return db;
}

Future<AppLocalizations> _l10n() async =>
    AppLocalizations.delegate.load(const Locale('en'));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() => AppLogger.init());

  // ── Path A: _tryLocalFallbackSignIn ───────────────────────────────────────

  group(
    'SI-LOCAL-01: _tryLocalFallbackSignIn — signOut() throws PlatformException',
    () {
      test(
        'returns true and logs warning event — NOT false / sign-in failure',
        () async {
          const email = 'local@example.com';
          const password = 'Password123!';

          // Seed a real local-born account so LocalAuthService.signIn succeeds.
          final db = await _seedLocalAccount(
            email: email,
            password: password,
            displayName: 'Local User',
          );
          addTearDown(() async => db.close());

          final mockAuth = MockAuthRepository();
          // signOut() throws the emulator platform exception.
          when(() => mockAuth.signOut()).thenThrow(
            PlatformException(
              code: 'Clear Failed',
              message: 'clearCredentialStateAsync failed',
            ),
          );
          // currentUser is used in authStateProvider internals.
          when(() => mockAuth.currentUser).thenReturn(null);
          when(
            () => mockAuth.onAuthStateChanged(),
          ).thenAnswer((_) => const Stream<AppUser?>.empty());

          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuth),
              userDatabaseProvider.overrideWithValue(db),
              // Registry is not read in the _tryLocalFallbackSignIn path, but
              // the provider is keepAlive so we supply a non-null placeholder.
              deviceRegistryProvider.overrideWithValue(
                DeviceRegistryDatabase(NativeDatabase.memory()),
              ),
              // _resetSessionContextForFreshSignIn reads routerProvider to call
              // pinGuard.lock() and restoreGuard.resetForNewSession(). Supply a
              // minimal stub router with working no-op guard implementations so
              // those calls do not throw.
              routerProvider.overrideWithValue(_StubAppRouter()),
            ],
          );
          addTearDown(container.dispose);

          // Keep signInControllerProvider alive during the test (it is autoDispose).
          // Without a listener Riverpod may dispose it between async gaps.
          final sub = container.listen(signInControllerProvider, (_, __) {});
          addTearDown(sub.close);

          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);

          final result = await controller.tryLocalFallbackSignInForTest(
            email: email,
            password: password,
            router: _StubRouter(),
            l10n: l10n,
          );

          // Must return true — auth succeeded; signOut failure is just cleanup.
          expect(
            result,
            isTrue,
            reason:
                'A throwing signOut() must NOT cause _tryLocalFallbackSignIn '
                'to return false. Auth succeeded; the platform signOut is '
                'best-effort cleanup only.',
          );

          // The warning event must be logged so operators can trace the issue.
          final history = AppLogger.instance.talker.history
              .map((e) => e.generateTextMessage())
              .toList();
          expect(
            history.any(
              (m) => m.contains('try_local_fallback_sign_in_sign_out_failed'),
            ),
            isTrue,
            reason:
                'Expected AppLogger.warning('
                'event: "try_local_fallback_sign_in_sign_out_failed") '
                'to be emitted. Talker history: $history',
          );

          // Critically: the "unexpected error" event must NOT be present —
          // the signOut() throw must be handled by the inner catch, not by
          // the outer catch that logs try_local_fallback_sign_in_failed.
          expect(
            history.any((m) => m.contains('try_local_fallback_sign_in_failed')),
            isFalse,
            reason:
                'try_local_fallback_sign_in_failed must NOT be emitted — the '
                'signOut() failure is not a sign-in failure.',
          );
        },
        // argon2id hashing is intentionally slow; allow enough headroom.
        timeout: const Timeout(Duration(seconds: 60)),
      );
    },
  );
}
