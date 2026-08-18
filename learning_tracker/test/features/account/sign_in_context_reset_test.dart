// Sign-in / session-establish context reset
//
// Owner bug: on sign-in the app must land in the user's OWN profile in NORMAL
// mode. It must NOT auto-restore the last tutored (talmid) selection or the
// parent-mode PIN unlock. Both pieces of state are keepAlive / live in the
// router singleton, so without an explicit reset they leak across a
// sign-out → sign-in (or an account switch) within the same process.
//
// This suite verifies:
//   • Runtime — the reset primitives behave as required:
//       - activeTutoredProfileSelection.exit() clears the talmid selection
//       - PinGuard.lock() clears the parent-PIN session
//         (parentPinAuthenticatedProfileId via onSessionLocked)
//       - selectedProfileId defaults to the own primary after a clear+select
//   • Wiring (end-to-end) — the reset actually fires at every in-process
//     session-establish chokepoint. AUD-t-account-02: this group used to grep
//     sign_in_controller.dart / account_picker_screen.dart as raw source text
//     for the reset call's token — which proves the token exists somewhere in
//     the file (even inside a comment or a dead branch), not that it runs
//     during a real sign-in. Every test below instead DRIVES the real call
//     chain (SignInController.signInWithEmail / a tapped AccountPickerScreen
//     account tile) against real Riverpod providers and asserts on the
//     resulting provider state — the same technique the "runtime semantics"
//     group above uses for the primitives themselves.

@Tags(['account', 'tutor_mode', 'sign_in'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
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
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_repositories.dart';

class _StubPinService implements PinService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Wiring-group mocks / fakes ───────────────────────────────────────────────

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

class _MockTutorGrantRepository extends Mock implements TutorGrantRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

/// Stands in for the `users/{uid}` account document behind
/// [FirestoreAccountRepositoryAdapter]. Both wiring tests below establish a
/// session through that adapter (`setCloudBornSessionFromFirebaseUser` in the
/// sign-in funnel, `ensureAccountForFirebaseUser` in the picker), so the
/// adapter must resolve to a predictable record instead of reaching live
/// Firestore. Stubbing `getAccount()` non-null is enough — the adapter
/// short-circuits before `createAccount`.
class _MockFirestoreAccountRepository extends Mock
    implements FirestoreAccountRepository {}

/// Stands in for [AccountFirebase] (Root Cause A, run12 device audit) — both
/// wiring tests below now also establish the account's named-app Firebase
/// session mid-funnel (`signInCloudAccountWithEmail`), which must not reach
/// live Firebase in a test. The returned [AccountFirebaseHandles] is never
/// inspected by these tests, only that establishing it completes.
class _MockAccountFirebase extends Mock implements AccountFirebase {}

class _FakeFirebaseApp extends Mock implements FirebaseApp {}

class _FakeFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _FakeFirebaseAuth extends Mock implements FirebaseAuth {}

AccountFirebaseHandles _fakeAccountFirebaseHandles({required String uid}) =>
    AccountFirebaseHandles(
      app: _FakeFirebaseApp(),
      firestore: _FakeFirebaseFirestore(),
      auth: _FakeFirebaseAuth(),
      uid: uid,
    );

/// The profile list the sign-in funnel routes on. Replaces the old in-memory
/// Firestore account/profile fixtures: post-P3-5 `_navigateAfterSignIn` reads
/// `profileRepositoryProvider.getProfiles()` (Firestore-direct) rather than
/// a locally materialised profile table, so "this account has N profiles" is
/// now controlled by the list handed to this fake.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._profiles);

  final List<LearnerProfileEntity> _profiles;

  @override
  Future<List<LearnerProfileEntity>> getProfiles() async => _profiles;

  @override
  Stream<List<LearnerProfileEntity>> watchProfiles() => Stream.value(_profiles);

  @override
  Future<LearnerProfileEntity?> getProfileById(String profileId) async =>
      _profiles.where((p) => p.profileId == profileId).firstOrNull;

  @override
  Future<int> countProfiles() async => _profiles.length;

  @override
  Future<LearnerProfileEntity> createProfile({
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  }) => throw UnimplementedError();

  @override
  Future<LearnerProfileEntity> updateProfile({
    required String profileId,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteProfile(String profileId, {bool allowLast = false}) =>
      throw UnimplementedError();
}

LearnerProfileEntity _profile(String profileId, String displayName) =>
    LearnerProfileEntity(
      profileId: profileId,
      displayName: displayName,
      mode: ProfileMode.adult,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AccountEntity _account(String uid, String email, String displayName) =>
    AccountEntity(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

/// A stub AuthStateNotifier that does NOT call `_init()` so it never
/// schedules async work that would race container disposal. The sign-in
/// controller reads `.notifier` to mutate the session state, so
/// `overrideWith()` is used (mirrors sign_in_controller_routing_test.dart).
class _NoInitAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

/// A StackRouter that accepts `replaceAll()` as a no-op. Only the reset
/// side-effects on Riverpod state are under test here, not navigation.
class _NoopRouter implements StackRouter {
  @override
  Future<void> replaceAll(
    List<PageRouteInfo<Object?>> routes, {
    OnNavigationFailure? onFailure,
    bool updateExistingRoutes = true,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

/// Dispose [container] then pump the tester to drain Riverpod scheduler
/// timers (mirrors sign_in_controller_routing_test.dart's helper).
Future<void> _disposeAndPump(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.dispose();
  await tester.pump(Duration.zero);
}

Widget _buildPickerApp({
  required ProviderContainer container,
  required StackRouter router,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const AccountPickerScreen(),
    ),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  group('sign-in context reset — runtime semantics', () {
    test('tutored selection is cleared by exit() (post-sign-in default = own '
        'profile, not a talmid view)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const selection = TutoredProfileSelection(
        profileId: 'talmid-1',
        ownerUid: 'owner-1',
        grantId: 'grant-1',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
        tutorOwnProfileId: 'tutor-own-1',
      );

      // Simulate a leftover talmid session from before sign-out.
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(selection);
      expect(container.read(activeTutoredProfileSelectionProvider), isNotNull);

      // The reset that every sign-in chokepoint performs.
      container.read(activeTutoredProfileSelectionProvider.notifier).exit();

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason:
            'after a fresh sign-in the user must NOT be in a talmid view — '
            'the active tutored selection must be cleared',
      );
    });

    test('PinGuard.lock() clears the parent-PIN session (parent mode is LOCKED '
        'after sign-in)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build a PinGuard wired exactly like routerProvider: onSessionLocked
      // clears parentPinAuthenticatedProfileId.
      final guard = PinGuard(
        pinSetupRoute: () => _FakePageRouteInfo(),
        pinService: _StubPinService(),
        promptForPin: () async => true,
        getScope: () => const PinScope.parent('profile-p1'),
        onSessionAuthenticated: (scope) {
          if (scope is PinScopeParent) {
            container
                .read(parentPinAuthenticatedProfileIdProvider.notifier)
                .setAuthenticated(scope.profileId);
          }
        },
        onSessionLocked: () {
          container
              .read(parentPinAuthenticatedProfileIdProvider.notifier)
              .clear();
        },
      );

      // Simulate parent mode already unlocked before sign-out.
      guard.markAuthenticated('profile-p1');
      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        'profile-p1',
        reason: 'precondition: parent mode unlocked for profile-p1',
      );

      // The reset that every sign-in chokepoint performs.
      guard.lock();

      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        isNull,
        reason:
            'after a fresh sign-in the parent-mode PIN gate must be LOCKED — '
            'the user must re-enter the PIN to reach parent management',
      );
    });

    test(
      'selected profile defaults to the own primary after clear + select',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Stale id from the previous account.
        container
            .read(selectedProfileIdProvider.notifier)
            .select('ulid-stale-999');
        // Sign-in chokepoints clear it, then select the own primary.
        container.read(selectedProfileIdProvider.notifier).clear();
        expect(container.read(selectedProfileIdProvider), isNull);

        container.read(selectedProfileIdProvider.notifier).select('ulid-own-1');
        expect(
          container.read(selectedProfileIdProvider),
          'ulid-own-1',
          reason:
              'after sign-in the selected profile must be the own primary, '
              'never a stale id or a tutored mirror',
        );
      },
    );
  });

  group('sign-in context reset — wiring (end-to-end)', () {
    testWidgets(
      'a fresh interactive cloud sign-in (the _navigateAfterSignIn funnel) '
      'clears a leaked talmid selection and locks the parent-PIN gate '
      'carried over from a prior session',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        final formKey = await _buildValidFormKey(tester);
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-reset-cloud-1',
            email: 'reset-cloud@example.com',
            displayName: 'Reset Cloud User',
            tier: 'cloudBorn',
            firebaseUid: const Value('fb-uid-reset-1'),
            dbFileName: 'user_acc_reset_cloud_1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final authRepo = MockAuthRepository();
        final checker = _MockInternetConnectionChecker();
        final tutorGrantRepo = _MockTutorGrantRepository();
        final accountRepo = _MockFirestoreAccountRepository();

        when(() => accountRepo.getAccount()).thenAnswer(
          (_) async => _account(
            'fb-uid-reset-1',
            'reset-cloud@example.com',
            'Reset Cloud User',
          ),
        );
        when(() => checker.hasConnection).thenAnswer((_) async => true);
        when(
          () => authRepo.signInWithEmail(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        const verifiedUser = AppUser(
          uid: 'fb-uid-reset-1',
          email: 'reset-cloud@example.com',
          displayName: 'Reset Cloud User',
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
        final accountFirebase = _MockAccountFirebase();
        when(
          () => accountFirebase.signInCloudAccountWithEmail(
            any<String>(),
            email: any<String>(named: 'email'),
            password: any<String>(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => _fakeAccountFirebaseHandles(uid: 'fb-uid-reset-1'),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            deviceRegistryProvider.overrideWithValue(registry),
            internetConnectionCheckerProvider.overrideWithValue(checker),
            tutorGrantRepositoryProvider.overrideWithValue(tutorGrantRepo),
            accountFirebaseRegistryProvider.overrideWithValue(accountFirebase),
            // The funnel establishes the session through
            // FirestoreAccountRepositoryAdapter and then routes on the
            // Firestore profile list — both are faked so the chain resolves
            // without touching live Firebase. One profile = the signed-in
            // user's own primary, the "lands in the own profile" case this
            // suite is about.
            firestoreAccountRepositoryProvider.overrideWith(
              (ref) async => accountRepo,
            ),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository([_profile('ulid-own-1', 'Own Profile')]),
            ),
            authStateProvider.overrideWith(_NoInitAuthStateNotifier.new),
          ],
        );

        // Simulate a leftover talmid session + unlocked parent-PIN gate from
        // a PRIOR account's session — both providers are keepAlive / live in
        // the router singleton, so nothing clears them automatically.
        const selection = TutoredProfileSelection(
          profileId: 'talmid-leak-1',
          ownerUid: 'owner-leak-1',
          grantId: 'grant-leak-1',
          permissions: TutorPermissions(
            canViewProgress: true,
            canViewContent: true,
          ),
          tutorOwnProfileId: 'tutor-own-leak-1',
        );
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(selection);
        // routerProvider is NOT overridden — this drives the SAME PinGuard
        // instance sign_in_controller.dart's _resetSessionContextForFreshSignIn
        // calls .lock() on in production.
        container
            .read(routerProvider)
            .pinGuard
            .markAuthenticated('profile-prior-1');
        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNotNull,
          reason:
              'precondition: a talmid selection leaked from a prior '
              'session',
        );
        expect(
          container.read(parentPinAuthenticatedProfileIdProvider),
          'profile-prior-1',
          reason:
              'precondition: the parent-PIN gate is unlocked from a '
              'prior session',
        );

        final l10n = await _l10n();
        final controller = container.read(signInControllerProvider.notifier);

        await controller.signInWithEmail(
          email: 'reset-cloud@example.com',
          password: 'p@ssword1',
          router: _NoopRouter(),
          l10n: l10n,
          formKey: formKey,
        );

        // cloudBorn + online + already-verified is the ONLY branch that
        // reaches _navigateAfterSignIn (and no other reset call site) — so
        // this exercises exactly the call the finding is about. Commenting
        // out `_resetSessionContextForFreshSignIn();` inside
        // _navigateAfterSignIn makes these two reads go red.
        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNull,
          reason:
              '_navigateAfterSignIn must clear the leaked talmid '
              'selection so a fresh sign-in lands in the own profile, not '
              "the prior session's talmid view",
        );
        expect(
          container.read(parentPinAuthenticatedProfileIdProvider),
          isNull,
          reason:
              '_navigateAfterSignIn must lock the parent-PIN gate so a '
              "fresh sign-in never inherits the prior session's unlocked "
              'parent mode',
        );

        await _disposeAndPump(tester, container);
        await registry.close();
      },
    );

    testWidgets('account-switch: tapping a cloud account with a valid session '
        '(_activateCloudAccountFromLocalData) clears a leaked talmid '
        'selection and locks the parent-PIN gate', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const targetUid = 'fb-uid-switch-instant';
      const targetEmail = 'switch-instant@test.cloud';
      const cloudUser = AppUser(
        uid: targetUid,
        email: targetEmail,
        displayName: 'Cloud Switch',
        emailVerified: true,
        providers: ['google.com'],
      );

      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      final auth = MockAuthRepository();
      final router = _MockStackRouter();
      final accountRepo = _MockFirestoreAccountRepository();

      // The Firestore account record _activateCloudAccountFromLocalData
      // resolves through firestoreAccountRepositoryAdapterProvider. It must
      // be non-null: a null entity short-circuits the method at the
      // "local data missing" snackbar, BEFORE the resets under test.
      when(() => accountRepo.getAccount()).thenAnswer(
        (_) async => _account(targetUid, targetEmail, 'Cloud Switch'),
      );

      when(() => auth.currentUser).thenReturn(cloudUser);
      when(
        () => auth.onAuthStateChanged(),
      ).thenAnswer((_) => Stream.value(cloudUser));
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => auth.reloadCurrentUser()).thenAnswer((_) async => cloudUser);
      when(() => router.push(any())).thenAnswer((_) async => null);
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-switch-instant',
          email: targetEmail,
          displayName: 'Cloud Switch',
          tier: 'cloudBorn',
          firebaseUid: const Value(targetUid),
          dbFileName: 'user_acc_switch_instant.db',
          createdAt: DateTime.utc(2026, 1, 4),
          lastUsedAt: DateTime.utc(2026, 1, 4),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          deviceRegistryProvider.overrideWithValue(registry),
          authRepositoryProvider.overrideWithValue(auth),
          firestoreAccountRepositoryProvider.overrideWith(
            (ref) async => accountRepo,
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(registry.close);

      // Leaked cross-account context this switch must clear.
      const selection = TutoredProfileSelection(
        profileId: 'talmid-switch-1',
        ownerUid: 'owner-switch-1',
        grantId: 'grant-switch-1',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
        tutorOwnProfileId: 'tutor-own-switch-1',
      );
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(selection);
      container
          .read(routerProvider)
          .pinGuard
          .markAuthenticated('profile-prev-account-1');
      expect(container.read(activeTutoredProfileSelectionProvider), isNotNull);
      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        'profile-prev-account-1',
      );

      await tester.pumpWidget(
        _buildPickerApp(container: container, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud Switch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason:
            '_activateCloudAccountFromLocalData must clear the '
            "previous account's leaked talmid selection",
      );
      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        isNull,
        reason:
            '_activateCloudAccountFromLocalData must lock the '
            'parent-PIN gate carried over from the previous account',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
