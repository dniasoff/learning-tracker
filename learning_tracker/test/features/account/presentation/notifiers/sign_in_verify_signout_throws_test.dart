// Regression tests for SI-VERIFY-01:
// signOut() in _ensureCloudEmailVerified can throw
// PlatformException(clearCredentialStateAsync…) on emulators / devices
// without Google Play Services. The function is called when the user
// cancels the email-verification dialog after signing in with Firebase.
// It must NOT surface a sign-in error to the user — the function should
// return false (sign-in rejected, correct outcome) and log a warning.
//
// Fix: the signOut() call is now wrapped in its own try/catch that logs a
// warning and continues, mirroring the analogous fix for SI-LOCAL-01.
//
// Red → Green:
//   BEFORE the fix: signOut() exception propagated out of
//   _ensureCloudEmailVerified and was caught by the outer catch(e) in
//   signInWithEmail, which called _mapAuthErrorFromException and surfaced
//   authErrSignInGeneric ("Sign-in failed") even though the only real issue
//   was that the user cancelled email verification.
//   The test was RED (ensureCloudEmailVerifiedForTest threw an exception).
//   AFTER the fix: signOut() is swallowed, the method returns false cleanly.
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

/// An unverified password-provider Firebase user.
const _unverifiedUser = AppUser(
  uid: 'uid-unverified',
  email: 'cloud@example.com',
  displayName: 'Cloud User',
  emailVerified: false,
  providers: ['password'],
);

Future<AppLocalizations> _l10n() async =>
    AppLocalizations.delegate.load(const Locale('en'));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() => AppLogger.init());

  group(
    'SI-VERIFY-01: _ensureCloudEmailVerified — signOut() throws PlatformException',
    () {
      test(
        'returns false (not throw) and logs warning — not propagating exception',
        () async {
          final mockAuth = _MockAuthRepository();

          // User is signed in but email unverified.
          when(() => mockAuth.currentUser).thenReturn(_unverifiedUser);

          // All reload attempts return the same unverified user so all
          // verification checks fail and the function reaches the signOut() call.
          when(
            () => mockAuth.reloadCurrentUser(),
          ).thenAnswer((_) async => _unverifiedUser);

          // checkActionCode throws (no pending code), so applyActionCode
          // is never reached. Mocktail still needs stubs for completeness.
          when(
            () => mockAuth.checkActionCode(any()),
          ).thenThrow(Exception('invalid-action-code'));
          when(() => mockAuth.applyActionCode(any())).thenAnswer((_) async {});

          // signOut() throws the emulator platform exception — this is the
          // exact failure SI-VERIFY-01 guards against.
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
            overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
          );
          addTearDown(container.dispose);

          // Keep the autoDispose notifier alive during the async test.
          final sub = container.listen(signInControllerProvider, (_, __) {});
          addTearDown(sub.close);

          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);

          // Wire up the _showVerification callback so it returns false
          // (user cancelled verification).
          controller.setCallbacks(
            showVerificationDialog: (_, __) async => false,
            showError: (_) {},
          );

          // Should return false cleanly — NOT throw.
          final result = await controller.ensureCloudEmailVerifiedForTest(
            'cloud@example.com',
            l10n,
          );

          // Must return false — user cancelled, but no exception should escape.
          expect(
            result,
            isFalse,
            reason:
                'A throwing signOut() must NOT cause '
                '_ensureCloudEmailVerified to throw. '
                'The method must return false cleanly.',
          );

          // The warning event must be logged so operators can trace the issue.
          final history = AppLogger.instance.talker.history
              .map((e) => e.generateTextMessage())
              .toList();
          expect(
            history.any(
              (m) => m.contains('ensure_cloud_email_verified_sign_out_failed'),
            ),
            isTrue,
            reason:
                'Expected AppLogger.warning('
                'event: "ensure_cloud_email_verified_sign_out_failed") '
                'to be emitted. Talker history: $history',
          );
        },
      );
    },
  );
}
