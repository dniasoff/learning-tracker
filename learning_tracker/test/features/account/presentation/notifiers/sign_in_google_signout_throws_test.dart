// Regression tests for SI-GOOGLE-01:
// signOut() cleanup calls in signInWithGoogle() can throw
// PlatformException(clearCredentialStateAsync…) on devices where
// CredentialManager is partially initialised.
//
// Failure path under test:
//   A) max-device-accounts path: device is full (5 accounts), signOut() cleans
//      up the just-signed-in Google user before returning the "device full" error.
//
// The former B) local-conflict case was removed because the current
// Firebase-backed controller no longer has that local-account branch.
//
// Fix: both signOut() calls are now wrapped in their own try/catch that log a
// warning and continue — mirroring the SI-LOCAL-01 and SI-VERIFY-01 fixes.
//
// Red → Green:
//   BEFORE the fix: signOut() exception escaped the inner block and was caught
//   by the outer catch(e) in signInWithGoogle, which called
//   _mapAuthErrorFromException and surfaced authErrSignInGeneric ("Sign-in
//   failed") — masking the real, user-actionable error (device full / upgrade).
//   AFTER the fix: the correct, specific max-account error message is shown.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_repositories.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal no-op router. These error paths return before any navigation call,
/// so no StackRouter methods are exercised.
class _StubRouter implements StackRouter {
  @override
  Future<void> replaceAll(
    List<PageRouteInfo<dynamic>> routes, {
    OnNavigationFailure? onFailure,
    bool updateExistingRoutes = true,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('StubRouter: unexpected call to ${i.memberName}');
}

class _MockDeviceRegistryDatabase extends Mock
    implements DeviceRegistryDatabase {}

final _kNow = DateTime.utc(2026, 1, 1);

const _googleUser = AppUser(
  uid: 'uid-google-user',
  email: 'google@example.com',
  displayName: 'Google User',
  emailVerified: true,
  providers: ['google.com'],
);

/// Builds the in-memory device-account values needed by the controller's
/// max-account guard. The registry itself is mocked; no account Drift DB is
/// opened by this Firebase-auth error-path test.
List<DeviceAccount> _seedAccounts(int count) => [
  for (var i = 0; i < count; i++)
    DeviceAccount(
      accountId: 'acc-$i',
      email: 'user$i@example.com',
      displayName: 'User $i',
      tier: 'localBorn',
      dbFileName: 'user_acc_$i.db',
      avatarIndex: 0,
      createdAt: _kNow,
      lastUsedAt: _kNow,
    ),
];

Future<AppLocalizations> _l10n() async =>
    AppLocalizations.delegate.load(const Locale('en'));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(
      const AppUser(
        uid: '',
        email: null,
        displayName: null,
        emailVerified: false,
        providers: [],
      ),
    );
  });

  setUp(() => AppLogger.init());

  // ── Path A: max-device-accounts ───────────────────────────────────────────

  group(
    'SI-GOOGLE-01-A: signInWithGoogle — max-accounts, signOut() throws',
    () {
      test('shows max-accounts error (not generic) and logs warning', () async {
        // Registry already full (kMaxDeviceAccounts = 5).
        final registry = _MockDeviceRegistryDatabase();
        when(() => registry.findByFirebaseUid(_googleUser.uid))
            .thenAnswer((_) async => null);
        when(() => registry.getAllAccounts())
            .thenAnswer((_) async => _seedAccounts(kMaxDeviceAccounts));

        final mockAuth = MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenAnswer((_) async {});
        // After Google sign-in, currentUser returns the Google account.
        when(() => mockAuth.currentUser).thenReturn(_googleUser);
        // Device full → signOut() to clean up; it throws.
        when(() => mockAuth.signOut()).thenThrow(
          PlatformException(
            code: 'Clear Failed',
            message: 'clearCredentialStateAsync failed',
          ),
        );
        when(
          () => mockAuth.onAuthStateChanged(),
        ).thenAnswer((_) => const Stream<AppUser?>.empty());

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            deviceRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(signInControllerProvider, (_, __) {});
        addTearDown(sub.close);

        final l10n = await _l10n();
        final controller = container.read(signInControllerProvider.notifier);
        String? capturedError;
        controller.setCallbacks(
          showVerificationDialog: (_, __) async => false,
          showError: (msg) => capturedError = msg,
        );

        await controller.signInWithGoogle(router: _StubRouter(), l10n: l10n);

        final state = container.read(signInControllerProvider);
        expect(
          state,
          isA<SignInError>(),
          reason: 'State must be SignInError when device is full.',
        );
        // The message must be the max-accounts error, NOT the generic error.
        final errorMsg = (state as SignInError).message;
        expect(
          errorMsg,
          isNot(l10n.authErrSignInGeneric),
          reason:
              'A throwing signOut() must NOT mask the real max-accounts '
              'error with the generic "Sign-in failed" message.',
        );
        expect(
          capturedError,
          isNot(l10n.authErrSignInGeneric),
          reason: 'showError callback must receive the specific error.',
        );

        // Warning must be logged.
        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any(
            (m) => m.contains('sign_in_google_max_accounts_sign_out_failed'),
          ),
          isTrue,
          reason:
              'Expected warning('
              'event: "sign_in_google_max_accounts_sign_out_failed") '
              'in talker history.',
        );
      });
    },
  );

  // The former local-conflict case was removed: the current Firebase-backed
  // controller no longer has a local-account conflict/sign-out branch.
}
