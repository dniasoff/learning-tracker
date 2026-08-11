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
//                                     navigates when the cached users/{uid}
//                                     account record resolves.
//   C. cloudBorn account + offline + account record unresolvable
//                                 → authLocalDataMissing shown, SignInError.
//   F. email-verification guard   → cloudBorn+online, unverified password
//                                   account shows dialog; dialog returns false
//                                   → signOut called, state returns to Idle.
//   G. Submitting state is observed during async execution.
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
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    show AuthStateNotifier, authStateProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
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

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFirestoreAccountRepository extends Mock
    implements FirestoreAccountRepository {}

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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A `users/{uid}` account repository that already holds a document — the
/// post-Drift stand-in for "this account has cached local data".
FirestoreAccountRepository _accountRepoWithExistingDoc({
  String uid = 'fb-uid-1',
  String email = 'cloud@example.com',
}) {
  final repo = _MockFirestoreAccountRepository();
  when(repo.getAccount).thenAnswer(
    (_) async => AccountEntity(
      uid: uid,
      email: email,
      displayName: 'Cloud User',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  return repo;
}

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
///
/// [profiles] is what `_navigateAfterSignIn` sees from
/// `profileRepositoryProvider.getProfiles()` and therefore drives the 0/1/many
/// routing branch. [accountRepo] backs both
/// `setCloudBornSessionFromFirebaseUser` and `_tryOfflineCloudRestore`; leaving
/// it null makes `FirestoreAccountRepositoryAdapter` throw
/// AccountRepositoryNotReadyException — the post-Drift analogue of "this
/// device has no cached data for the account".
ProviderContainer _makeContainer({
  required MockAuthRepository authRepo,
  required DeviceRegistryDatabase registry,
  required _MockInternetConnectionChecker checker,
  required _MockTutorGrantRepository tutorGrantRepo,
  List<LearnerProfileEntity> profiles = const [],
  FirestoreAccountRepository? accountRepo,
}) {
  final profileRepo = _MockProfileRepository();
  when(profileRepo.getProfiles).thenAnswer((_) async => profiles);
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      deviceRegistryProvider.overrideWithValue(registry),
      internetConnectionCheckerProvider.overrideWithValue(checker),
      tutorGrantRepositoryProvider.overrideWithValue(tutorGrantRepo),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      firestoreAccountRepositoryProvider.overrideWith(
        (ref) async => accountRepo,
      ),
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
            accountRepo: _accountRepoWithExistingDoc(),
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
        },
      );
    },
  );

  // ── Branch B: cloudBorn offline → offline-cloud-restore navigates ──────────

  group(
    'Branch B — cloudBorn account, offline: offline-cloud-restore navigates',
    () {
      testWidgets(
        '_tryOfflineCloudRestore navigates to AppShellRoute when the cached '
        'users/{uid} account record resolves',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(registry);

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();

          // Offline.
          when(() => checker.hasConnection).thenAnswer((_) async => false);
          when(() => authRepo.currentUser).thenReturn(null);
          when(() => authRepo.signOut()).thenAnswer((_) async {});

          // The offline restore helper now reads the account record through
          // FirestoreAccountRepositoryAdapter — Firestore's own offline
          // persistence serves the cached users/{uid} doc, which this mock
          // stands in for.
          final container = _makeContainer(
            authRepo: authRepo,
            registry: registry,
            checker: checker,
            tutorGrantRepo: tutorGrantRepo,
            accountRepo: _accountRepoWithExistingDoc(),
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
                'Offline cloud restore must navigate when the account record '
                'resolves',
          );

          // State must be Idle.
          expect(container.read(signInControllerProvider), isA<SignInIdle>());

          await _tearDownContainer(tester, container);
          await registry.close();
        },
      );
    },
  );

  // ── Branch C: cloudBorn offline + no local data → error ───────────────────

  group(
    'Branch C — cloudBorn account, offline, no account record: shows error',
    () {
      testWidgets(
        'SignInError(authLocalDataMissing) when offline-restore finds nothing',
        (tester) async {
          final formKey = await _buildValidFormKey(tester);
          // Registry has the cloud account, but no account repository resolves
          // (see _makeContainer's accountRepo doc).
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          await _seedCloudAccount(registry);

          final authRepo = MockAuthRepository();
          final checker = _MockInternetConnectionChecker();
          final tutorGrantRepo = _MockTutorGrantRepository();

          // Offline.
          when(() => checker.hasConnection).thenAnswer((_) async => false);
          when(() => authRepo.currentUser).thenReturn(null);
          when(() => authRepo.signOut()).thenAnswer((_) async {});

          // accountRepo intentionally omitted: the adapter then throws
          // AccountRepositoryNotReadyException, the post-Drift analogue of
          // "no cached data on this device for the account".
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
                'offline cloudBorn with no resolvable account record must '
                'show authLocalDataMissing',
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

  // ── Branch F: email-verification guard ─────────────────────────────────────
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
        accountRepo: _accountRepoWithExistingDoc(),
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
    });
  });
}
