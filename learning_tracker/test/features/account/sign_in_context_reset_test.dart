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
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
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
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
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
        tutorOwnProfileId: 7,
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
        getScope: () => const PinScope.parent(3),
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
      guard.markAuthenticated(3);
      expect(
        container.read(parentPinAuthenticatedProfileIdProvider),
        3,
        reason: 'precondition: parent mode unlocked for profile 3',
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
            .select(999, ulid: 'ulid-999');
        // Sign-in chokepoints clear it, then select the own primary.
        container.read(selectedProfileIdProvider.notifier).clear();
        expect(container.read(selectedProfileIdProvider), isNull);

        container
            .read(selectedProfileIdProvider.notifier)
            .select(1, ulid: 'ulid-1');
        expect(
          container.read(selectedProfileIdProvider),
          1,
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
        final db = UserDatabase(NativeDatabase.memory());

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

        final container = ProviderContainer(
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
          tutorOwnProfileId: 7,
        );
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(selection);
        // routerProvider is NOT overridden — this drives the SAME PinGuard
        // instance sign_in_controller.dart's _resetSessionContextForFreshSignIn
        // calls .lock() on in production.
        container.read(routerProvider).pinGuard.markAuthenticated(3);
        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNotNull,
          reason:
              'precondition: a talmid selection leaked from a prior '
              'session',
        );
        expect(
          container.read(parentPinAuthenticatedProfileIdProvider),
          3,
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
        await db.close();
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
      final userDb = UserDatabase(NativeDatabase.memory());
      final auth = MockAuthRepository();
      final router = _MockStackRouter();

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
      await userDb
          .into(userDb.accounts)
          .insert(
            AccountsCompanion.insert(
              email: targetEmail,
              tier: 'cloudBorn',
              displayName: 'Cloud Switch',
              firebaseUid: const Value(targetUid),
              createdAt: DateTime.utc(2026, 1, 4),
              updatedAt: DateTime.utc(2026, 1, 4),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          deviceRegistryProvider.overrideWithValue(registry),
          authRepositoryProvider.overrideWithValue(auth),
          userDatabaseProvider.overrideWith((ref) => userDb),
          syncOrchestratorProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async {
        await registry.close();
        await userDb.close();
      });

      // Leaked cross-account context this switch must clear.
      const selection = TutoredProfileSelection(
        profileId: 'talmid-switch-1',
        ownerUid: 'owner-switch-1',
        grantId: 'grant-switch-1',
        permissions: TutorPermissions(
          canViewProgress: true,
          canViewContent: true,
        ),
        tutorOwnProfileId: 9,
      );
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(selection);
      container.read(routerProvider).pinGuard.markAuthenticated(4);
      expect(container.read(activeTutoredProfileSelectionProvider), isNotNull);
      expect(container.read(parentPinAuthenticatedProfileIdProvider), 4);

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
