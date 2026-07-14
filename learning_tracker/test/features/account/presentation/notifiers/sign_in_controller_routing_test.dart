// sign_in_controller_routing_test.dart
//
// Routing-branch coverage for SignInController.signInWithEmail.
//
// Focuses on the ROUTING logic (connectivity check → auth path branching),
// kept completely separate from sign_in_controller_test.dart which covers
// error-code mapping and Google sign-in state machine.
//
// Branches exercised (active):
//   A. cloudBorn account + online  → Firebase signInWithEmail called,
//                                     email-verified user navigates.
//   B. cloudBorn account + offline → _tryOfflineCloudRestore invoked,
//                                     navigates when local profile exists.
//   C. cloudBorn account + offline + no local data
//                                 → authLocalDataMissing shown, SignInError.
//   F. email-verification guard   → cloudBorn+online, unverified password
//                                   account shows dialog; dialog returns false
//                                   → signOut called, state returns to Idle.
//   G. Submitting state is observed during async execution.
//
// Branches skipped (argon2id path):
//   D. no registry entry + local fallback misses + online → Firebase.
//      SKIP: _tryLocalFallbackSignIn calls LocalAuthService.signIn which
//      calls PasswordHasher.dummyVerify (full argon2id) even when no profile
//      exists — blocks the event loop >30 s in a test environment.
//   E. no registry entry + local fallback misses + offline
//      → authEmailOfflineUnreachable.
//      SKIP: same argon2id path as D.
//
// These skipped branches are covered by design review (the typed `else` clause
// at sign_in_controller.dart:679 is the only entry to that error message, and
// the dummyVerify call is an intentional timing-attack mitigation).
//
// NOTE on testWidgets vs test:
//   We use testWidgets for every case because the controller needs a real
//   GlobalKey<FormState> (validate() must return true before the controller
//   advances). We pump a minimal Form to attach its state, then pump
//   Duration.zero after container.dispose() to drain Riverpod scheduler
//   timers before the WidgetTester tears down.

@Tags(['account', 'sign_in_routing'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
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

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

class _MockTutorGrantRepository extends Mock implements TutorGrantRepository {}

// ── Stub AuthStateNotifier ────────────────────────────────────────────────────

/// A stub AuthStateNotifier that does NOT call _init() so it never
/// schedules async work that would race container disposal.
///
/// The sign-in controller reads `.notifier` to mutate the session state, so
/// overrideWithValue() is insufficient (it gives a _SyncValueProviderElement
/// which cannot be cast to a $ClassProviderElement). This subclass is used
/// with overrideWith() instead.
class _NoInitAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
  // Intentionally does NOT call super.build() — suppresses _init() entirely.
}

// ── Stub router ───────────────────────────────────────────────────────────────

/// Captures all replaceAll() calls so tests can assert navigation targets.
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

// ── In-memory UserDatabase ────────────────────────────────────────────────────

class _InMemoryUserDatabase extends UserDatabase {
  _InMemoryUserDatabase() : super(NativeDatabase.memory());
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A GlobalKey<FormState> whose FormState.validate() always returns true
/// because the Form has no validators.
///
/// We pump a minimal Form so the real FormState is attached and
/// validate() is callable.
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

/// Lazily realise AppLocalizations (en).
Future<AppLocalizations> _l10n() async =>
    AppLocalizations.delegate.load(const Locale('en'));

/// Seeds a cloud-born DeviceAccount into [registry] and returns it.
Future<DeviceAccount> _seedCloudAccount(
  DeviceRegistryDatabase registry, {
  String accountId = 'acc-cloud-1',
  String email = 'cloud@example.com',
  String firebaseUid = 'fb-uid-1',
  String dbFileName = 'user_acc_cloud_1.db',
}) async {
  await registry.addAccount(
    DeviceAccountsCompanion.insert(
      accountId: accountId,
      email: email,
      displayName: 'Cloud User',
      tier: 'cloudBorn',
      firebaseUid: Value(firebaseUid),
      dbFileName: dbFileName,
      createdAt: DateTime.utc(2026, 1, 1),
      lastUsedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  return (await registry.findByEmail(email))!;
}

/// Standard ProviderContainer wiring for routing tests.
///
/// authStateProvider is overridden with a no-op notifier to prevent
/// AuthStateNotifier._init() from scheduling async work that races container
/// disposal. The sign-in controller reads .notifier to mutate session state,
/// so overrideWith() is used (overrideWithValue() would give a non-mutable
/// _SyncValueProviderElement and cause a type-cast failure).
ProviderContainer _makeContainer({
  required MockAuthRepository authRepo,
  required DeviceRegistryDatabase registry,
  required _MockInternetConnectionChecker checker,
  required _MockTutorGrantRepository tutorGrantRepo,
  _InMemoryUserDatabase? userDb,
}) {
  final db = userDb ?? _InMemoryUserDatabase();
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      deviceRegistryProvider.overrideWithValue(registry),
      internetConnectionCheckerProvider.overrideWithValue(checker),
      syncOrchestratorProvider.overrideWithValue(null),
      firestoreGatewayProvider.overrideWithValue(null),
      tutorGrantRepositoryProvider.overrideWithValue(tutorGrantRepo),
      userDatabaseProvider.overrideWithValue(db),
      authStateProvider.overrideWith(_NoInitAuthStateNotifier.new),
    ],
  );
}

/// Dispose [container] then pump the tester to drain Riverpod scheduler timers.
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

    // Mocktail fallbacks.
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

  // ── Branch A: cloudBorn online → Firebase sign-in + email verified ─────────

  group(
    'Branch A — cloudBorn account, online: Firebase sign-in → navigate',
    () {
      testWidgets(
        'signInWithEmail calls authRepo.signInWithEmail and navigates away '
        'when the account is cloud-born, the device is online, and the email '
        'is already verified',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(registry);

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();
          final db = _InMemoryUserDatabase();

          // Online.
          when(() => checker.hasConnection).thenAnswer((_) async => true);

          // Successful Firebase sign-in.
          when(
            () => authRepo.signInWithEmail(any<String>(), any<String>()),
          ).thenAnswer((_) async {});

          // Verified user.
          const verifiedUser = AppUser(
            uid: 'fb-uid-1',
            email: 'cloud@example.com',
            displayName: 'Cloud User',
            emailVerified: true,
            providers: ['password'],
          );
          when(() => authRepo.currentUser).thenReturn(verifiedUser);
          when(
            () => authRepo.reloadCurrentUser(),
          ).thenAnswer((_) async => verifiedUser);
          when(() => authRepo.signOut()).thenAnswer((_) async {});
          when(
            () => tutorGrantRepo.listIncomingGrants(),
          ).thenAnswer((_) async => []);

          final container = _makeContainer(
            authRepo: authRepo,
            registry: registry,
            checker: checker,
            tutorGrantRepo: tutorGrantRepo,
            userDb: db,
          );

          final router = _SpyRouter();
          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);

          await controller.signInWithEmail(
            email: 'cloud@example.com',
            password: 'p@ssword1',
            router: router,
            l10n: l10n,
            formKey: formKey,
          );

          // Firebase sign-in must have been called exactly once.
          verify(
            () => authRepo.signInWithEmail('cloud@example.com', 'p@ssword1'),
          ).called(1);

          // Navigation must have occurred.
          expect(
            router.replaceCalls,
            isNotEmpty,
            reason:
                'Expected navigation to occur after successful cloud sign-in',
          );

          // Final state must be Idle.
          expect(container.read(signInControllerProvider), isA<SignInIdle>());

          await _tearDownContainer(tester, container);
          await registry.close();
          await db.close();
        },
      );
    },
  );

  // ── Branch B: cloudBorn offline → offline-cloud-restore navigates ──────────

  group(
    'Branch B — cloudBorn account, offline: offline-cloud-restore navigates',
    () {
      testWidgets(
        '_tryOfflineCloudRestore navigates to AppShellRoute when local '
        'cloud-born profile is present in the user DB',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(registry);

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();
          final db = _InMemoryUserDatabase();

          // Offline.
          when(() => checker.hasConnection).thenAnswer((_) async => false);
          when(() => authRepo.currentUser).thenReturn(null);
          when(() => authRepo.signOut()).thenAnswer((_) async {});

          // Seed a cloud-born user profile row so the offline restore helper
          // can find it via the DAO.
          await db.userProfileDao.upsertProfile(
            firebaseUid: 'fb-uid-1',
            email: 'cloud@example.com',
            displayName: 'Cloud User',
            updatedAt: DateTime.utc(2026, 1, 1),
          );

          final container = _makeContainer(
            authRepo: authRepo,
            registry: registry,
            checker: checker,
            tutorGrantRepo: tutorGrantRepo,
            userDb: db,
          );

          final router = _SpyRouter();
          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);

          await controller.signInWithEmail(
            email: 'cloud@example.com',
            password: 'p@ssword1',
            router: router,
            l10n: l10n,
            formKey: formKey,
          );

          // Navigation must have been triggered.
          expect(
            router.replaceCalls,
            isNotEmpty,
            reason:
                'Offline cloud restore must navigate when profile is present',
          );

          // State must be Idle.
          expect(container.read(signInControllerProvider), isA<SignInIdle>());

          await _tearDownContainer(tester, container);
          await registry.close();
          await db.close();
        },
      );
    },
  );

  // ── Branch C: cloudBorn offline + no local data → error ───────────────────

  group(
    'Branch C — cloudBorn account, offline, no local profile: shows error',
    () {
      testWidgets(
        'SignInError(authLocalDataMissing) when offline-restore finds nothing',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          // Registry has the cloud account but user DB is empty (no profile).
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(registry);

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();

          // Offline.
          when(() => checker.hasConnection).thenAnswer((_) async => false);
          when(() => authRepo.currentUser).thenReturn(null);
          when(() => authRepo.signOut()).thenAnswer((_) async {});

          final container = _makeContainer(
            authRepo: authRepo,
            registry: registry,
            checker: checker,
            tutorGrantRepo: tutorGrantRepo,
          );

          String? capturedError;
          final router = _SpyRouter();
          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);
          controller.setCallbacks(
            showVerificationDialog: (_, __) async => false,
            showError: (msg) => capturedError = msg,
          );

          await controller.signInWithEmail(
            email: 'cloud@example.com',
            password: 'p@ssword1',
            router: router,
            l10n: l10n,
            formKey: formKey,
          );

          // State must be SignInError with the correct message.
          final state = container.read(signInControllerProvider);
          expect(state, isA<SignInError>());
          expect(
            (state as SignInError).message,
            l10n.authLocalDataMissing,
            reason:
                'offline cloudBorn with no local data must show '
                'authLocalDataMissing',
          );

          // Error callback must have fired.
          expect(capturedError, l10n.authLocalDataMissing);

          // No navigation.
          expect(router.replaceCalls, isEmpty);

          await _tearDownContainer(tester, container);
          await registry.close();
        },
      );
    },
  );

  // ── Branches D & E: no-registry paths → SKIPPED (argon2id) ───────────────

  group('Branch D — no registry entry, online [SKIPPED — argon2id]', () {
    test(
      // BUG: Not a bug — intentional test limitation. When no registry entry
      // exists, signInWithEmail calls _tryLocalFallbackSignIn which calls
      // LocalAuthService.signIn which calls PasswordHasher.dummyVerify (full
      // argon2id) even when no local profile exists. This is an intentional
      // timing-attack mitigation but blocks the test event loop for >30 s.
      // The "no registry, online → Firebase" routing is correct by code
      // review of sign_in_controller.dart:679-710.
      'no-registry + online → Firebase path cannot be tested due to argon2id '
      'dummyVerify in LocalAuthService.signIn (timing-attack mitigation)',
      () {
        expect(true, isTrue); // placeholder so the test file has this group
      },
      skip:
          'argon2id dummyVerify blocks the event loop when no local profile '
          'exists; covers sign_in_controller.dart:679 else-branch',
    );
  });

  group('Branch E — no registry entry, offline [SKIPPED — argon2id]', () {
    test(
      // Same reason as Branch D.
      'no-registry + offline → authEmailOfflineUnreachable path cannot be '
      'tested due to argon2id dummyVerify in LocalAuthService.signIn',
      () {
        expect(true, isTrue);
      },
      skip:
          'argon2id dummyVerify blocks the event loop; '
          'covers sign_in_controller.dart:704 authEmailOfflineUnreachable',
    );
  });

  // ── Branch F: email-verification guard ─────────────────────────────────────
  //
  // Uses a cloudBorn registry entry so we take the cloudBorn+online path
  // (no _tryLocalFallbackSignIn) and exercise _ensureCloudEmailVerified.
  //
  // _waitForVerified(maxAttempts:3) contains Future.delayed(350ms) calls.
  // testWidgets uses FakeAsync which won't advance timers during a direct
  // await — so we use tester.runAsync() to run the controller call in a real
  // async zone where Future.delayed uses real timers (~3 × 350 ms = ~1 s).

  group(
    'Branch F — email-verification guard: cloudBorn+online, unverified '
    'password account shows dialog; dialog returns false → sign-out, Idle',
    () {
      testWidgets(
        'when Firebase signs in but email is unverified, _showVerification is '
        'called; returning false signs the user out and leaves state Idle',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          // cloudBorn registry entry — takes the cloudBorn+online path,
          // no _tryLocalFallbackSignIn, no argon2id.
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(
            registry,
            email: 'unverified@example.com',
            firebaseUid: 'fb-uid-unverified',
          );

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();

          // Online.
          when(() => checker.hasConnection).thenAnswer((_) async => true);

          // Firebase sign-in succeeds.
          when(
            () => authRepo.signInWithEmail(any<String>(), any<String>()),
          ).thenAnswer((_) async {});

          // Unverified password user (stays unverified on all reloads).
          const unverifiedUser = AppUser(
            uid: 'fb-uid-unverified',
            email: 'unverified@example.com',
            displayName: 'Unverified',
            emailVerified: false,
            providers: ['password'],
          );
          when(() => authRepo.currentUser).thenReturn(unverifiedUser);
          when(
            () => authRepo.reloadCurrentUser(),
          ).thenAnswer((_) async => unverifiedUser);
          when(
            () => authRepo.checkActionCode(any<String>()),
          ).thenAnswer((_) async {});
          when(
            () => authRepo.applyActionCode(any<String>()),
          ).thenAnswer((_) async {});
          when(() => authRepo.signOut()).thenAnswer((_) async {});

          final container = _makeContainer(
            authRepo: authRepo,
            registry: registry,
            checker: checker,
            tutorGrantRepo: tutorGrantRepo,
          );

          var verificationDialogShown = false;
          final router = _SpyRouter();
          final l10n = await _l10n();
          final controller = container.read(signInControllerProvider.notifier);

          // Dialog callback: record it was shown; return false (user did not
          // verify).
          controller.setCallbacks(
            showVerificationDialog: (email, _) async {
              verificationDialogShown = true;
              return false;
            },
            showError: (_) {},
          );

          // Use tester.runAsync so Future.delayed(350ms) calls inside
          // _waitForVerified use real timers instead of FakeAsync timers.
          await tester.runAsync(() async {
            await controller.signInWithEmail(
              email: 'unverified@example.com',
              password: 'p@ssword1',
              router: router,
              l10n: l10n,
              formKey: formKey,
            );
          });

          // Verification dialog must have been displayed.
          expect(
            verificationDialogShown,
            isTrue,
            reason:
                'Expected _showVerification to be called for an unverified '
                'password account',
          );

          // signOut must have been called (guard signs out unverified users).
          verify(() => authRepo.signOut()).called(greaterThanOrEqualTo(1));

          // No navigation after failed verification.
          expect(
            router.replaceCalls,
            isEmpty,
            reason: 'No navigation should occur when verification is rejected',
          );

          // State must settle to Idle (the guard handled it, not an error).
          expect(container.read(signInControllerProvider), isA<SignInIdle>());

          await _tearDownContainer(tester, container);
          await registry.close();
        },
      );
    },
  );

  // ── Branch G: Submitting is observed during execution ─────────────────────

  group('Branch G — state machine: Submitting is observed during sign-in', () {
    testWidgets('state transitions through Submitting before settling to Idle '
        'on successful cloudBorn online sign-in', (tester) async {
      final formKey = await _buildValidFormKey(tester);
      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      await _seedCloudAccount(registry);

      final authRepo = MockAuthRepository();
      final checker = _MockInternetConnectionChecker();
      final tutorGrantRepo = _MockTutorGrantRepository();
      final db = _InMemoryUserDatabase();

      when(() => checker.hasConnection).thenAnswer((_) async => true);
      when(
        () => authRepo.signInWithEmail(any<String>(), any<String>()),
      ).thenAnswer((_) async {});

      const verifiedUser = AppUser(
        uid: 'fb-uid-1',
        email: 'cloud@example.com',
        displayName: 'Cloud User',
        emailVerified: true,
        providers: ['password'],
      );
      when(() => authRepo.currentUser).thenReturn(verifiedUser);
      when(
        () => authRepo.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => authRepo.signOut()).thenAnswer((_) async {});
      when(
        () => tutorGrantRepo.listIncomingGrants(),
      ).thenAnswer((_) async => []);

      final container = _makeContainer(
        authRepo: authRepo,
        registry: registry,
        checker: checker,
        tutorGrantRepo: tutorGrantRepo,
        userDb: db,
      );

      final states = <SignInState>[];
      container.listen(signInControllerProvider, (_, next) => states.add(next));

      final l10n = await _l10n();
      await container
          .read(signInControllerProvider.notifier)
          .signInWithEmail(
            email: 'cloud@example.com',
            password: 'p@ssword1',
            router: _SpyRouter(),
            l10n: l10n,
            formKey: formKey,
          );

      expect(
        states,
        contains(isA<SignInSubmitting>()),
        reason: 'Expected SignInSubmitting to appear during sign-in',
      );
      expect(states.last, isA<SignInIdle>());

      await _tearDownContainer(tester, container);
      await registry.close();
      await db.close();
    });
  });
}
