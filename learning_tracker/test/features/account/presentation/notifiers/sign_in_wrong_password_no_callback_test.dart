// sign_in_wrong_password_no_callback_test.dart
//
// Regression test for P0 bug: wrong-password cloud sign-in shows no error
// when callbacks are not yet registered.
//
// Root cause: SignInScreen.initState calls setCallbacks() inside a
// postFrameCallback.  If the controller is recreated (autoDispose) and
// signInWithEmail completes/errors before that postFrameCallback fires (or if
// setCallbacks is simply not called for any reason), _showError is null and
// the null-safe `?.call` silently drops the error — the user sees the screen
// return to sign-in with no snackbar.
//
// The fix: call setCallbacks() synchronously in initState (no postFrameCallback
// wrapper) so the callback is ALWAYS registered before any user action can fire
// signInWithEmail.
//
// This test verifies the CONTROLLER side: when signInWithEmail is called with a
// cloud-born account + online but Firebase throws invalid-credential, the
// controller MUST:
//   1. Transition state to SignInError (so a watcher can react).
//   2. Call _showError (so the snackbar fires).
//
// The test also verifies the "no callback set at all" scenario: state MUST be
// SignInError regardless of whether setCallbacks was called (the state machine
// is the fallback source of truth that the screen can watch).

@Tags(['account', 'sign_in_wrong_password'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    show AuthStateNotifier, authStateProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_repositories.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

class _MockTutorGrantRepository extends Mock implements TutorGrantRepository {}

class _MockDeviceRegistryDatabase extends Mock
    implements DeviceRegistryDatabase {}

// ── Stub AuthStateNotifier ────────────────────────────────────────────────────

class _NoInitAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

// ── Stub router ───────────────────────────────────────────────────────────────

class _SpyRouter implements StackRouter {
  final List<List<PageRouteInfo<Object?>>> replaceCalls = [];

  @override
  Future<void> replaceAll(
    List<PageRouteInfo<Object?>> routes, {
    OnNavigationFailure? onFailure,
    bool updateExistingRoutes = true,
  }) async {
    replaceCalls.add(List<PageRouteInfo<Object?>>.unmodifiable(routes));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<GlobalKey<FormState>> _buildValidFormKey(WidgetTester tester) async {
  final key = GlobalKey<FormState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(key: key, child: const SizedBox()),
      ),
    ),
  );
  return key;
}

Future<AppLocalizations> _l10n() async =>
    AppLocalizations.delegate.load(const Locale('en'));

DeviceAccount _cloudAccount({
  String accountId = 'acc-cloud-wp',
  String email = 'cloud@example.com',
  String firebaseUid = 'fb-uid-wp',
  String dbFileName = 'user_acc_cloud_wp.db',
}) => DeviceAccount(
  accountId: accountId,
  email: email,
  displayName: 'Cloud User',
  tier: 'cloudBorn',
  firebaseUid: firebaseUid,
  dbFileName: dbFileName,
  avatarIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  lastUsedAt: DateTime.utc(2026, 1, 1),
);

ProviderContainer _makeContainer({
  required MockAuthRepository authRepo,
  required _MockDeviceRegistryDatabase registry,
  required _MockInternetConnectionChecker checker,
  required _MockTutorGrantRepository tutorGrantRepo,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      deviceRegistryProvider.overrideWithValue(registry),
      internetConnectionCheckerProvider.overrideWithValue(checker),
      tutorGrantRepositoryProvider.overrideWithValue(tutorGrantRepo),
      authStateProvider.overrideWith(_NoInitAuthStateNotifier.new),
    ],
  );
}

Future<void> _tearDownContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.dispose();
  await tester.pump(Duration.zero);
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    AppLogger.init();
    SharedPreferences.setMockInitialValues({});
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── P0 regression: wrong-password cloud sign-in — _showError MUST fire ───────
  //
  // This is the primary regression guard for the bug where entering a bad
  // password for a cloud account returned silently to the sign-in screen with
  // no snackbar.  Reproduced when setCallbacks() was wrapped in a
  // postFrameCallback and the controller had already been called before that
  // callback fired (race window on first frame).
  //
  // The fix moves setCallbacks() out of the postFrameCallback so it is always
  // registered before any user interaction is possible.

  group('P0 regression — wrong-password cloud sign-in always shows error', () {
    testWidgets(
      'SI-WP-01: cloudBorn + online + wrong password → SignInError AND '
      '_showError called even when callbacks set BEFORE signInWithEmail '
      '(baseline: correct behaviour when callbacks are registered)',
      (tester) async {
        final formKey = await _buildValidFormKey(tester);
        final registry = _MockDeviceRegistryDatabase();
        final account = _cloudAccount();
        when(() => registry.findByEmail(account.email)).thenAnswer((_) async => account);

        final authRepo = MockAuthRepository();
        final checker = _MockInternetConnectionChecker();
        final tutorGrantRepo = _MockTutorGrantRepository();

        when(() => checker.hasConnection).thenAnswer((_) async => true);
        // Firebase throws invalid-credential for a wrong password on
        // projects with email-enumeration-protection enabled.
        when(
          () => authRepo.signInWithEmail(any<String>(), any<String>()),
        ).thenThrow(
          Exception('[firebase_auth/invalid-credential] bad password'),
        );
        when(() => authRepo.currentUser).thenReturn(null);
        when(() => authRepo.signOut()).thenAnswer((_) async {});

        final container = _makeContainer(
          authRepo: authRepo,
          registry: registry,
          checker: checker,
          tutorGrantRepo: tutorGrantRepo,
        );
        addTearDown(() => _tearDownContainer(tester, container));

        // Callbacks set BEFORE sign-in (the correct post-fix path).
        String? capturedError;
        final controller = container.read(signInControllerProvider.notifier);
        controller.setCallbacks(
          showVerificationDialog: (_, __) async => false,
          showError: (msg) => capturedError = msg,
        );

        final l10n = await _l10n();
        await controller.signInWithEmail(
          email: 'cloud@example.com',
          password: 'wrong-password',
          router: _SpyRouter(),
          l10n: l10n,
          formKey: formKey,
        );

        final state = container.read(signInControllerProvider);
        expect(
          state,
          isA<SignInError>(),
          reason:
              'SI-WP-01: wrong-password must transition to SignInError, '
              'not stay Idle or Submitting',
        );
        expect(
          (state as SignInError).message,
          l10n.authErrWrongPassword,
          reason:
              'SI-WP-01: invalid-credential must map to authErrWrongPassword',
        );
        expect(
          capturedError,
          l10n.authErrWrongPassword,
          reason:
              'SI-WP-01: _showError callback must be invoked so the snackbar '
              'fires — this is the only user-visible error path',
        );

        // Drain the zero-duration Timer that ProviderContainer.read()
        // scheduled internally when its temporary subscription closed
        // (autoDispose bookkeeping) — must happen before this test body
        // returns so flutter_test's pending-timer invariant check (which
        // runs immediately after, before any addTearDown callback) is
        // satisfied. Actual resource cleanup stays in addTearDown above,
        // registered right after creation, so it still fires even if an
        // expect() throws before reaching here.
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'SI-WP-02: cloudBorn + online + wrong password → SignInError even '
      'when callbacks are NOT set (simulates the pre-fix postFrameCallback '
      'race — callbacks are null when sign-in errors)',
      (tester) async {
        final formKey = await _buildValidFormKey(tester);
        final registry = _MockDeviceRegistryDatabase();
        final account = _cloudAccount();
        when(() => registry.findByEmail(account.email)).thenAnswer((_) async => account);

        final authRepo = MockAuthRepository();
        final checker = _MockInternetConnectionChecker();
        final tutorGrantRepo = _MockTutorGrantRepository();

        when(() => checker.hasConnection).thenAnswer((_) async => true);
        when(
          () => authRepo.signInWithEmail(any<String>(), any<String>()),
        ).thenThrow(
          Exception('[firebase_auth/invalid-credential] bad password'),
        );
        when(() => authRepo.currentUser).thenReturn(null);
        when(() => authRepo.signOut()).thenAnswer((_) async {});

        final container = _makeContainer(
          authRepo: authRepo,
          registry: registry,
          checker: checker,
          tutorGrantRepo: tutorGrantRepo,
        );
        addTearDown(() => _tearDownContainer(tester, container));

        // Intentionally do NOT call setCallbacks() — simulates the
        // pre-fix race where postFrameCallback hadn't fired yet.
        final controller = container.read(signInControllerProvider.notifier);
        final l10n = await _l10n();

        await controller.signInWithEmail(
          email: 'cloud@example.com',
          password: 'wrong-password',
          router: _SpyRouter(),
          l10n: l10n,
          formKey: formKey,
        );

        // Even without callbacks, the state machine MUST reflect the error.
        // The screen observes state via ref.watch(signInControllerProvider)
        // and must be able to surface the error from SignInError.message when
        // _showError is unavailable.
        final state = container.read(signInControllerProvider);
        expect(
          state,
          isA<SignInError>(),
          reason:
              'SI-WP-02: state must be SignInError even when no callbacks '
              'are set — the screen can observe state directly to surface '
              'the error message',
        );
        expect(
          (state as SignInError).message,
          l10n.authErrWrongPassword,
          reason:
              'SI-WP-02: invalid-credential must map to authErrWrongPassword '
              'regardless of callback registration status',
        );

        // Drain the zero-duration Timer that ProviderContainer.read()
        // scheduled internally when its temporary subscription closed
        // (autoDispose bookkeeping) — must happen before this test body
        // returns so flutter_test's pending-timer invariant check (which
        // runs immediately after, before any addTearDown callback) is
        // satisfied. Actual resource cleanup stays in addTearDown above,
        // registered right after creation, so it still fires even if an
        // expect() throws before reaching here.
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'SI-WP-03: wrong-password with wrong-password error code (not just '
      'invalid-credential) also surfaces correctly via _showError',
      (tester) async {
        final formKey = await _buildValidFormKey(tester);
        final registry = _MockDeviceRegistryDatabase();
        final account = _cloudAccount();
        when(() => registry.findByEmail(account.email)).thenAnswer((_) async => account);

        final authRepo = MockAuthRepository();
        final checker = _MockInternetConnectionChecker();
        final tutorGrantRepo = _MockTutorGrantRepository();

        when(() => checker.hasConnection).thenAnswer((_) async => true);
        when(
          () => authRepo.signInWithEmail(any<String>(), any<String>()),
        ).thenThrow(Exception('[firebase_auth/wrong-password] wrong password'));
        when(() => authRepo.currentUser).thenReturn(null);
        when(() => authRepo.signOut()).thenAnswer((_) async {});

        final container = _makeContainer(
          authRepo: authRepo,
          registry: registry,
          checker: checker,
          tutorGrantRepo: tutorGrantRepo,
        );
        addTearDown(() => _tearDownContainer(tester, container));

        String? capturedError;
        final controller = container.read(signInControllerProvider.notifier);
        controller.setCallbacks(
          showVerificationDialog: (_, __) async => false,
          showError: (msg) => capturedError = msg,
        );

        final l10n = await _l10n();
        await controller.signInWithEmail(
          email: 'cloud@example.com',
          password: 'wrong-password',
          router: _SpyRouter(),
          l10n: l10n,
          formKey: formKey,
        );

        final state = container.read(signInControllerProvider);
        expect(state, isA<SignInError>());
        expect((state as SignInError).message, l10n.authErrWrongPassword);
        expect(capturedError, l10n.authErrWrongPassword);

        // Drain the zero-duration Timer that ProviderContainer.read()
        // scheduled internally when its temporary subscription closed
        // (autoDispose bookkeeping) — must happen before this test body
        // returns so flutter_test's pending-timer invariant check (which
        // runs immediately after, before any addTearDown callback) is
        // satisfied. Actual resource cleanup stays in addTearDown above,
        // registered right after creation, so it still fires even if an
        // expect() throws before reaching here.
        await tester.pump(Duration.zero);
      },
    );
  });
}
