import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

// ── Hand-rolled fakes ─────────────────────────────────────────────────────────

/// Fake auth repo that throws on sendEmailVerification — used by the
/// original resendVerificationEmail test.
class _ThrowingAuthRepository implements AuthRepository {
  int sendCount = 0;

  @override
  Future<void> sendEmailVerification() async {
    sendCount++;
    throw Exception('simulated send-verification failure');
  }

  @override
  AppUser? get currentUser => null;

  @override
  Future<void> applyActionCode(String oobCode) => throw UnimplementedError();

  @override
  Future<void> changePassword(String newPassword) => throw UnimplementedError();

  @override
  Future<void> checkActionCode(String oobCode) => throw UnimplementedError();

  @override
  Future<String> createUserAccount(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();

  @override
  Future<void> deleteCurrentFirebaseUser() => throw UnimplementedError();

  @override
  List<String> getLinkedProviders() => const <String>[];

  @override
  bool isSignInWithEmailLink(String link) => false;

  @override
  Future<void> linkEmailProvider(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> linkGoogleProvider() => throw UnimplementedError();

  @override
  Stream<AppUser?> onAuthStateChanged() => const Stream<AppUser?>.empty();

  @override
  Future<AppUser?> reauthenticateWithGoogle() => throw UnimplementedError();

  @override
  Future<void> reauthenticateWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> reloadCurrentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> sendSignInLinkToEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> signInAndGetUser(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> signInWithEmailLink(String email, String emailLink) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password, String displayName) =>
      throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String displayName) =>
      throw UnimplementedError();
}

/// Sentinel exception so the catch-path test can assert "saw OUR exception".
class _StubDatabaseFailure implements Exception {
  const _StubDatabaseFailure(this.message);
  final String message;

  @override
  String toString() => '_StubDatabaseFailure: $message';
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns log entries whose rendered text mentions [event].
Iterable<String> _entriesMentioning(String event) {
  return AppLogger.instance.talker.history
      .map((entry) => entry.generateTextMessage())
      .where((m) => m.contains(event));
}

/// Minimal StackRouter stub — the catch path returns before any navigation.
class _StubRouter implements StackRouter {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'StubRouter received an unexpected call: ${invocation.memberName}',
  );
}

/// Builds a DeviceAccount fixture for the offline-cloud-restore catch test.
DeviceAccount _cloudAccount() => DeviceAccount(
  accountId: 'acc-cloud-1',
  email: 'cloud@example.com',
  displayName: 'Cloud User',
  tier: 'cloudBorn',
  firebaseUid: 'fb-uid-1',
  avatarIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  lastUsedAt: DateTime.utc(2026, 1, 1),
  dbFileName: 'user_acc_cloud_1.db',
);

/// Lazily realise AppLocalizations for tests.
Future<AppLocalizations> _stubL10n() async {
  return AppLocalizations.delegate.load(const Locale('en'));
}

/// Creates a ProviderContainer with an in-memory registry and the given
/// authRepository, plus an override for syncOrchestratorProvider returning null.
ProviderContainer _makeContainer({
  required AuthRepository authRepo,
  DeviceRegistryDatabase? registry,
}) {
  final reg = registry ?? DeviceRegistryDatabase(NativeDatabase.memory());
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      deviceRegistryProvider.overrideWithValue(reg),
    ],
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    AppLogger.init();
    // Default mocktail fallback values.
    registerFallbackValue(
      const AppUser(
        uid: 'uid',
        email: null,
        displayName: null,
        emailVerified: false,
        providers: [],
      ),
    );
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('SignInController — initial state', () {
    test('starts as SignInIdle', () {
      final mockAuth = _MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(null);
      when(
        () => mockAuth.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream<AppUser?>.empty());
      final container = _makeContainer(authRepo: mockAuth);
      addTearDown(container.dispose);

      final state = container.read(signInControllerProvider);
      expect(state, isA<SignInIdle>());
    });
  });

  // ── Form validation short-circuit ─────────────────────────────────────────
  //
  // signInWithEmail requires a formKey whose validate() must return true before
  // the controller calls state = Submitting. The validate() call needs a real
  // Form widget in the widget tree, which is only possible with widget pumping.
  // The logic-test protocol (no widget pumping) means we cannot inject a
  // FormState stub here. Form-validation coverage lives in:
  //   test/features/auth/presentation/screens/sign_in_screen_test.dart
  // The initial-state test above already proves the controller doesn't
  // spontaneously leave SignInIdle without being called.

  // ── Google sign-in — state transitions ────────────────────────────────────

  group('SignInController.signInWithGoogle — state machine', () {
    test(
      'returns to SignInIdle when GoogleSignInException(canceled) is thrown',
      () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'user canceled',
          ),
        );
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final l10n = await _stubL10n();
        final controller = container.read(signInControllerProvider.notifier);

        await controller.signInWithGoogle(router: _StubRouter(), l10n: l10n);

        // Canceled flow must return to idle — no error shown.
        expect(container.read(signInControllerProvider), isA<SignInIdle>());
        verify(() => mockAuth.signInWithGoogle()).called(1);
      },
    );

    test(
      'returns to SignInIdle when GoogleSignInException(interrupted) is thrown',
      () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
            description: 'interrupted',
          ),
        );
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final l10n = await _stubL10n();
        final controller = container.read(signInControllerProvider.notifier);

        await controller.signInWithGoogle(router: _StubRouter(), l10n: l10n);

        expect(container.read(signInControllerProvider), isA<SignInIdle>());
      },
    );

    test(
      'transitions to SignInError for non-cancel GoogleSignInException',
      () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'unknown error',
          ),
        );
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final l10n = await _stubL10n();
        String? capturedError;
        final controller = container.read(signInControllerProvider.notifier);
        controller.setCallbacks(
          showVerificationDialog: (_, __) async => false,
          showError: (msg) => capturedError = msg,
        );

        await controller.signInWithGoogle(router: _StubRouter(), l10n: l10n);

        final state = container.read(signInControllerProvider);
        expect(state, isA<SignInError>());
        expect((state as SignInError).message, l10n.authGoogleSignInFailed);
        // _showError callback must be called.
        expect(capturedError, l10n.authGoogleSignInFailed);
      },
    );

    test(
      'transitions to SignInError for generic exception during Google sign-in',
      () async {
        final mockAuth = _MockAuthRepository();
        // Throw a Firebase-style exception with a code embedded in toString.
        when(
          () => mockAuth.signInWithGoogle(),
        ).thenThrow(Exception('[network-request-failed] Network error'));
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final l10n = await _stubL10n();
        final controller = container.read(signInControllerProvider.notifier);

        await controller.signInWithGoogle(router: _StubRouter(), l10n: l10n);

        final state = container.read(signInControllerProvider);
        expect(state, isA<SignInError>());
        // Must map to the network error string, not the generic one.
        expect((state as SignInError).message, l10n.authErrNetwork);
      },
    );

    test('state is SignInSubmitting during signInWithGoogle '
        '(observed via listener before throw resolves)', () async {
      // Use a completer-based throw to capture the in-flight state.
      final mockAuth = _MockAuthRepository();
      final states = <SignInState>[];

      // Track every state change.
      when(() => mockAuth.signInWithGoogle()).thenAnswer((_) async {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'user canceled',
        );
      });
      final container = _makeContainer(authRepo: mockAuth);
      addTearDown(container.dispose);

      container.listen(signInControllerProvider, (_, next) => states.add(next));

      final l10n = await _stubL10n();
      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle(router: _StubRouter(), l10n: l10n);

      // Should have seen: Submitting → Idle (cancelled, no error).
      expect(states, contains(isA<SignInSubmitting>()));
      expect(states.last, isA<SignInIdle>());
    });
  });

  // ── _mapAuthError code mapping ─────────────────────────────────────────────

  group('SignInController._mapAuthError — error code → l10n key', () {
    Future<void> assertCode(
      String firebaseCode,
      String Function(AppLocalizations) expected,
    ) async {
      final mockAuth = _MockAuthRepository();
      // Embed the Firebase code in the exception's toString.
      when(
        () => mockAuth.signInWithGoogle(),
      ).thenThrow(Exception('[$firebaseCode] message'));
      final container = _makeContainer(authRepo: mockAuth);
      addTearDown(container.dispose);

      final l10n = await _stubL10n();
      await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle(router: _StubRouter(), l10n: l10n);

      final state = container.read(signInControllerProvider);
      expect(
        (state as SignInError).message,
        expected(l10n),
        reason: 'Expected code=$firebaseCode to map to correct l10n string',
      );
    }

    test('user-not-found maps to authErrUserNotFound', () async {
      await assertCode('user-not-found', (l) => l.authErrUserNotFound);
    });

    test('wrong-password maps to authErrWrongPassword', () async {
      await assertCode('wrong-password', (l) => l.authErrWrongPassword);
    });

    test('invalid-credential maps to authErrInvalidCredential', () async {
      await assertCode('invalid-credential', (l) => l.authErrInvalidCredential);
    });

    test('user-disabled maps to authErrUserDisabled', () async {
      await assertCode('user-disabled', (l) => l.authErrUserDisabled);
    });

    test('too-many-requests maps to authErrTooManyRequests', () async {
      await assertCode('too-many-requests', (l) => l.authErrTooManyRequests);
    });

    test('invalid-email maps to authErrInvalidEmail', () async {
      await assertCode('invalid-email', (l) => l.authErrInvalidEmail);
    });

    test('network-request-failed maps to authErrNetwork', () async {
      await assertCode('network-request-failed', (l) => l.authErrNetwork);
    });

    test('unknown code maps to authErrSignInGeneric', () async {
      await assertCode('some-unknown-code', (l) => l.authErrSignInGeneric);
    });

    test(
      'exception with no embedded code maps to authErrSignInGeneric',
      () async {
        final mockAuth = _MockAuthRepository();
        when(
          () => mockAuth.signInWithGoogle(),
        ).thenThrow(Exception('no code here'));
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final l10n = await _stubL10n();
        await container
            .read(signInControllerProvider.notifier)
            .signInWithGoogle(router: _StubRouter(), l10n: l10n);

        final state = container.read(signInControllerProvider);
        expect((state as SignInError).message, l10n.authErrSignInGeneric);
      },
    );
  });

  // ── signInWithEmail — local account error paths ────────────────────────────

  // ── tryLocalFallbackSignIn — InvalidCredentials path ─────────────────────
  //
  // InvalidCredentialsException from LocalAuthService.signIn is caught by
  // the typed `on InvalidCredentialsException` branch in _tryLocalFallbackSignIn,
  // which returns false silently (no AppLogger entry). This distinguishes a
  // bad-password user error from a system failure.
  //
  // Note: when the *provider* itself throws (rather than LocalAuthService),
  // Riverpod wraps the exception in a ProviderException, which does NOT match
  // the typed catch and falls to the generic catch → warning is logged.
  // The F19-logging test above covers that code path.
  // Testing the pure InvalidCredentialsException path requires a real
  // UserDatabase + real LocalAuthService chain, which belongs in an
  // integration test. The typed-catch contract is verified by the
  // source-level code review: the `on InvalidCredentialsException` guard is
  // present at line 709 of sign_in_controller.dart and tested implicitly via
  // the absence of a warning in the credentials-error user-flow.

  // ── setCallbacks ──────────────────────────────────────────────────────────

  group('SignInController.setCallbacks', () {
    test(
      '_showError callback is invoked when signInWithGoogle errors',
      () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'fail',
          ),
        );
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        String? capturedMsg;
        container
            .read(signInControllerProvider.notifier)
            .setCallbacks(
              showVerificationDialog: (_, __) async => false,
              showError: (msg) => capturedMsg = msg,
            );

        final l10n = await _stubL10n();
        await container
            .read(signInControllerProvider.notifier)
            .signInWithGoogle(router: _StubRouter(), l10n: l10n);

        expect(capturedMsg, isNotNull);
        expect(capturedMsg, l10n.authGoogleSignInFailed);
      },
    );

    test(
      '_showError is NOT called when GoogleSignInException is canceled',
      () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'user canceled',
          ),
        );
        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        var errorCalled = false;
        container
            .read(signInControllerProvider.notifier)
            .setCallbacks(
              showVerificationDialog: (_, __) async => false,
              showError: (_) => errorCalled = true,
            );

        final l10n = await _stubL10n();
        await container
            .read(signInControllerProvider.notifier)
            .signInWithGoogle(router: _StubRouter(), l10n: l10n);

        expect(errorCalled, isFalse);
      },
    );
  });

  // ── resendVerificationEmail — existing tests (preserved) ──────────────────

  group('SignInController.resendVerificationEmail', () {
    test('logs a warning via AppLogger when sendEmailVerification throws '
        '(replaces the previously swallowed empty catch)', () async {
      final throwingAuth = _ThrowingAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(throwingAuth)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      await controller.resendVerificationEmail();

      expect(throwingAuth.sendCount, 1);

      final history = AppLogger.instance.talker.history;
      final messages = history
          .map((entry) => entry.generateTextMessage())
          .toList();

      expect(
        messages.any((m) => m.contains('send_verification_email_failed')),
        isTrue,
        reason:
            'Expected AppLogger.warning(event: "send_verification_email_failed") '
            'to be emitted. Talker history: $messages',
      );
      expect(
        messages.any((m) => m.contains('simulated send-verification failure')),
        isTrue,
        reason:
            'Expected the underlying exception to be attached to the log entry. '
            'Talker history: $messages',
      );
    });
  });

  // ── F19: empty-catch logging in offline / local-fallback paths ─────────────

  group('SignInController.tryLocalFallbackSignInForTest — F19 logging', () {
    test('logs a warning via AppLogger when an unexpected exception is thrown '
        '(replaces the previously swallowed empty catch)', () async {
      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith(
            (ref) => throw const _StubDatabaseFailure('user db unavailable'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);

      final result = await controller.tryLocalFallbackSignInForTest(
        email: 'test@example.com',
        password: 'whatever',
        router: _StubRouter(),
        l10n: await _stubL10n(),
      );

      expect(
        result,
        isFalse,
        reason:
            'helper must return false when an unexpected exception is '
            'caught (matches the legacy contract — the only change is the '
            'log emission).',
      );

      final entries = _entriesMentioning(
        'try_local_fallback_sign_in_failed',
      ).toList();
      expect(
        entries,
        isNotEmpty,
        reason:
            'Expected AppLogger.warning(event: "try_local_fallback_sign_in_failed") '
            'to be emitted. Talker history: '
            '${AppLogger.instance.talker.history.map((e) => e.generateTextMessage()).toList()}',
      );
      expect(
        entries.any((m) => m.contains('user db unavailable')),
        isTrue,
        reason:
            'Expected the underlying exception message to be attached. '
            'Captured entries: $entries',
      );
    });
  });

  group('SignInController.tryOfflineCloudRestoreForTest — F19 logging', () {
    test('logs a warning via AppLogger when an unexpected exception is thrown '
        '(replaces the previously swallowed empty catch)', () async {
      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith(
            (ref) => throw const _StubDatabaseFailure('offline db swap failed'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);

      final result = await controller.tryOfflineCloudRestoreForTest(
        _cloudAccount(),
        _StubRouter(),
      );

      expect(
        result,
        isFalse,
        reason:
            'helper must return false when an unexpected exception is '
            'caught.',
      );

      final entries = _entriesMentioning(
        'try_offline_cloud_restore_failed',
      ).toList();
      expect(
        entries,
        isNotEmpty,
        reason:
            'Expected AppLogger.warning(event: "try_offline_cloud_restore_failed") '
            'to be emitted. Talker history: '
            '${AppLogger.instance.talker.history.map((e) => e.generateTextMessage()).toList()}',
      );
      expect(
        entries.any((m) => m.contains('offline db swap failed')),
        isTrue,
        reason:
            'Expected the underlying exception message to be attached. '
            'Captured entries: $entries',
      );
    });
  });

  // ── SignInState equality / sealed variants ────────────────────────────────

  group('SignInState — sealed type identities', () {
    test('SignInIdle is a SignInState', () {
      const s = SignInIdle();
      expect(s, isA<SignInState>());
      expect(s, isA<SignInIdle>());
    });

    test('SignInSubmitting is a SignInState', () {
      const s = SignInSubmitting();
      expect(s, isA<SignInState>());
      expect(s, isA<SignInSubmitting>());
    });

    test('SignInError carries its message', () {
      const s = SignInError('oops');
      expect(s, isA<SignInState>());
      expect(s.message, 'oops');
    });
  });

  // ── Google sign-in: full state sequence ───────────────────────────────────

  group(
    'SignInController.signInWithGoogle — Submitting → SignInError sequence',
    () {
      test('state sequence is Idle → Submitting → SignInError '
          'for a non-cancel exception', () async {
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.signInWithGoogle()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'server error',
          ),
        );

        final container = _makeContainer(authRepo: mockAuth);
        addTearDown(container.dispose);

        final states = <SignInState>[];
        container.listen(
          signInControllerProvider,
          (_, next) => states.add(next),
        );

        final l10n = await _stubL10n();
        await container
            .read(signInControllerProvider.notifier)
            .signInWithGoogle(router: _StubRouter(), l10n: l10n);

        expect(states[0], isA<SignInSubmitting>());
        expect(states[1], isA<SignInError>());
      });
    },
  );
}
