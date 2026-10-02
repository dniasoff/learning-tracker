// AccountPicker — switching accounts must NEVER sign out (DEC-34).
//
// Locks the behaviour Daniel asked about: tapping a saved account switches in
// place (swap DB + session + reload to AppShell) and keeps you signed in. The
// picker must never call AuthRepository.signOut() and must not bounce a
// local/valid account to the sign-in screen.

@Tags(['account', 'multi_account'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/features/account/domain/models/account_auth_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/firestore_fake.dart';
import '../../../helpers/firestore_fixtures.dart';
import '../../../mocks/mock_repositories.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

AppUser _user(String uid, String email) => AppUser(
  uid: uid,
  email: email,
  displayName: email,
  emailVerified: true,
  providers: const ['google.com'],
);

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  late DeviceRegistryDatabase registry;
  late FakeFirebaseFirestore firestore;
  late MockAuthRepository auth;
  late _MockStackRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    firestore = createFakeFirestore();
    auth = MockAuthRepository();
    router = _MockStackRouter();

    when(() => auth.currentUser).thenReturn(null);
    // AUD-account-18: _AccountTile now watches the reactive auth-state stream
    // (instead of ref.read-ing auth.currentUser) to compute hasValidSession.
    // Mirror whatever auth.currentUser is stubbed to at subscribe time so the
    // reactive value matches the synchronous one the rest of this suite sets.
    when(
      () => auth.onAuthStateChanged(),
    ).thenAnswer((_) => Stream.value(auth.currentUser));
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => router.replaceAll(any())).thenAnswer((_) async {});
    // DNI-520: every account has its OWN named-app session. Default: none.
    when(() => auth.restoreSession(any())).thenAnswer((_) async => null);
    when(() => auth.forAccount(any())).thenReturn(auth);

    // One saved LOCAL account in the device registry…
    await registry.addAccount(
      DeviceAccountsCompanion.insert(
        accountId: 'acc-local',
        email: 'local@test.local',
        displayName: 'Local User',
        tier: 'localBorn',
        firebaseUid: const Value('fb-uid-local'),
        dbFileName: 'user_acc_acc-local.db',
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await seedAccount(
      firestore,
      uid: 'fb-uid-local',
      email: 'local@test.local',
      displayName: 'Local User',
    );
  });

  tearDown(() async {
    await registry.close();
  });

  Widget buildApp({InternetConnectionChecker? connectivity}) => ProviderScope(
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      firestoreAccountRepositoryProvider.overrideWith(
        (ref) async => FirestoreAccountRepository(
          firestore: firestore,
          uid: auth.currentUser?.uid ?? 'fb-uid-local',
        ),
      ),
      if (connectivity != null)
        internetConnectionCheckerProvider.overrideWithValue(connectivity),
    ],
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

  testWidgets(
    'tapping a saved account switches to AppShell without signing out (DEC-34)',
    (tester) async {
      // DNI-520 AC-2: a local account gets an anonymous session on its OWN
      // named app (createAnonymousAccount) before it is activated.
      when(
        () => auth.currentUser,
      ).thenReturn(_user('fb-uid-local', 'local@test.local'));
      when(
        () => auth.ensureAnonymousSession('acc-local'),
      ).thenAnswer((_) async => _user('fb-uid-local', 'local@test.local'));
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => auth.currentUser);

      await tester.pumpWidget(buildApp());
      await tester.pump(); // resolve the getAllAccounts() FutureBuilder
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Local User'), findsOneWidget);

      await tester.tap(find.text('Local User'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // THE invariant: switching never signs out.
      verifyNever(() => auth.signOut());
      // AC-2: the local account's named app got its anonymous session; no
      // credential sign-in happened.
      verify(() => auth.ensureAnonymousSession('acc-local')).called(1);
      verifyNever(() => auth.pickGoogleAccount());

      // It reloads into the app shell — not the sign-in screen.
      final replaced = verify(() => router.replaceAll(captureAny())).captured;
      expect(replaced, isNotEmpty, reason: 'switch should reload the shell');
      final routes = (replaced.last as List).cast<PageRouteInfo>();
      expect(
        routes.any((r) => r is AppShellRoute),
        isTrue,
        reason: 'a saved-account switch must land on AppShellRoute',
      );
      expect(
        routes.any((r) => r is SignInRoute),
        isFalse,
        reason: 'switching must NOT route to sign-in',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Cloud→cloud switch: auto re-authenticate Firebase ─────────────────────
  //
  // DNI-520: every account keeps its own named-app session. Tapping a cloud
  // account whose OWN session is missing/stale must sign THAT named app in
  // again (Google picker → signInToAccountWithGoogle), verify the uid
  // matches, then activate.
  group('cloud-account switch re-authenticates Firebase', () {
    const targetUid = 'fb-uid-cloud-A';
    const targetEmail = 'cloud-a@test.cloud';

    Future<void> seedCloudAccount() async {
      // Live session belongs to a DIFFERENT account (B) — mismatch.
      when(
        () => auth.currentUser,
      ).thenReturn(_user('fb-uid-B', 'b@test.cloud'));
      when(() => auth.signOut()).thenAnswer((_) async {});
      // The live Firebase-auth fake is the source of the active identity.
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => auth.currentUser);
      // Default: no silent session available → the switch falls through to the
      // interactive picker. Individual silent-path tests override this.
      when(
        () => auth.pickGoogleAccountSilently(),
      ).thenAnswer((_) async => null);
      when(() => auth.pickGoogleAccount()).thenAnswer(
        (_) async =>
            const GoogleAccountPick(idToken: 'tok', email: targetEmail),
      );

      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-cloud-a',
          email: targetEmail,
          displayName: 'Cloud A',
          tier: 'cloudBorn',
          dbFileName: 'user_acc_acc-cloud-a.db',
          firebaseUid: const Value(targetUid),
          createdAt: DateTime.utc(2026, 1, 2),
          lastUsedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      await SharedPreferences.getInstance().then(
        (prefs) => AccountAuthProviderStore(
          prefs,
        ).write('acc-cloud-a', AccountAuthProvider.google),
      );
      await seedAccount(
        firestore,
        uid: targetUid,
        email: targetEmail,
        displayName: 'Cloud A',
      );
    }

    testWidgets(
      'uid mismatch + re-auth success → signInWithGoogle + activate AppShell',
      (tester) async {
        await seedCloudAccount();
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);

        // The target account's named app signs in as the TARGET identity.
        when(
          () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
        ).thenAnswer((_) async {
          when(
            () => auth.currentUser,
          ).thenReturn(_user(targetUid, targetEmail));
          return _user(targetUid, targetEmail);
        });

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Re-auth ran on the TARGET account's own named app.
        verify(
          () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
        ).called(1);
        // Live uid now equals the target account's firebaseUid (matched).
        expect(auth.currentUser?.uid, targetUid);

        // Switch landed on the app shell, not the sign-in screen.
        final replaced = verify(() => router.replaceAll(captureAny())).captured;
        final routes = (replaced.last as List).cast<PageRouteInfo>();
        expect(routes.any((r) => r is AppShellRoute), isTrue);
        expect(routes.any((r) => r is SignInRoute), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('uid mismatch after re-auth → abort, no activation', (
      tester,
    ) async {
      await seedCloudAccount();
      final online = _MockInternetConnectionChecker();
      when(() => online.hasConnection).thenAnswer((_) async => true);

      // uid churn: the named app signs in as a different uid.
      when(
        () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
      ).thenAnswer((_) async => _user('fb-uid-WRONG', targetEmail));

      await tester.pumpWidget(buildApp(connectivity: online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
      ).called(1);
      // Wrong identity → that account's named app is signed out and the
      // switch is aborted: NO navigation to AppShell.
      verify(() => auth.forAccount('acc-cloud-a')).called(1);
      verify(() => auth.signOut()).called(1);
      verifyNever(() => router.replaceAll(any()));
    });

    testWidgets('a Google account with another email is rejected BEFORE any '
        'Firebase sign-in', (tester) async {
      await seedCloudAccount();
      final online = _MockInternetConnectionChecker();
      when(() => online.hasConnection).thenAnswer((_) async => true);
      when(() => auth.pickGoogleAccount()).thenAnswer(
        (_) async =>
            const GoogleAccountPick(idToken: 'tok', email: 'wrong@test.cloud'),
      );

      await tester.pumpWidget(buildApp(connectivity: online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(() => auth.signInToAccountWithGoogle(any(), any()));
      verifyNever(() => router.replaceAll(any()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Silent-first re-auth (no picker) ─────────────────────────────────
    testWidgets(
      'silent re-auth resolves the target uid → activate with NO picker',
      (tester) async {
        await seedCloudAccount();
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);

        // Silent pick returns the TARGET account's cached Google session.
        when(() => auth.pickGoogleAccountSilently()).thenAnswer(
          (_) async =>
              const GoogleAccountPick(idToken: 'silent', email: targetEmail),
        );
        when(
          () => auth.signInToAccountWithGoogle('acc-cloud-a', 'silent'),
        ).thenAnswer((_) async {
          when(
            () => auth.currentUser,
          ).thenReturn(_user(targetUid, targetEmail));
          return _user(targetUid, targetEmail);
        });

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Silent path was attempted and succeeded for the target uid.
        verify(() => auth.pickGoogleAccountSilently()).called(1);
        // The interactive picker was NEVER shown.
        verifyNever(() => auth.pickGoogleAccount());

        // Switch landed on the app shell.
        final replaced = verify(() => router.replaceAll(captureAny())).captured;
        final routes = (replaced.last as List).cast<PageRouteInfo>();
        expect(routes.any((r) => r is AppShellRoute), isTrue);
        expect(routes.any((r) => r is SignInRoute), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'silent re-auth returns null → falls back to interactive picker',
      (tester) async {
        await seedCloudAccount();
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);

        // No cached silent session.
        when(
          () => auth.pickGoogleAccountSilently(),
        ).thenAnswer((_) async => null);
        // Interactive picker then resolves the target identity.
        when(
          () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
        ).thenAnswer((_) async => _user(targetUid, targetEmail));

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => auth.pickGoogleAccountSilently()).called(1);
        // Fell back to the interactive picker.
        verify(() => auth.pickGoogleAccount()).called(1);
        final replaced = verify(() => router.replaceAll(captureAny())).captured;
        final routes = (replaced.last as List).cast<PageRouteInfo>();
        expect(routes.any((r) => r is AppShellRoute), isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'silent re-auth resolves the WRONG uid → falls back to interactive picker',
      (tester) async {
        await seedCloudAccount();
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);

        // Silent resolves a DIFFERENT cached account — must not activate it.
        when(() => auth.pickGoogleAccountSilently()).thenAnswer(
          (_) async => const GoogleAccountPick(
            idToken: 'other',
            email: 'other@test.cloud',
          ),
        );
        // Interactive picker then resolves the correct target identity.
        when(
          () => auth.signInToAccountWithGoogle('acc-cloud-a', 'tok'),
        ).thenAnswer((_) async => _user(targetUid, targetEmail));

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => auth.pickGoogleAccountSilently()).called(1);
        // Wrong silent account → never signed in; the picker was shown.
        verifyNever(() => auth.signInToAccountWithGoogle(any(), 'other'));
        verify(() => auth.pickGoogleAccount()).called(1);
        final replaced = verify(() => router.replaceAll(captureAny())).captured;
        final routes = (replaced.last as List).cast<PageRouteInfo>();
        expect(routes.any((r) => r is AppShellRoute), isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('re-auth user-cancel → clean no-op with no activation', (
      tester,
    ) async {
      await seedCloudAccount();
      final online = _MockInternetConnectionChecker();
      when(() => online.hasConnection).thenAnswer((_) async => true);

      // User cancels the native account picker.
      when(() => auth.pickGoogleAccount()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      await tester.pumpWidget(buildApp(connectivity: online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => auth.pickGoogleAccount()).called(1);
      // Cancellation must not activate the target's local session or navigate
      // into the shell with a phantom/partial auth state.
      verifyNever(() => router.replaceAll(any()));
      verifyNever(() => auth.signOut());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'email/password account prompts for password and signs in with email',
      (tester) async {
        await seedCloudAccount();
        final prefs = await SharedPreferences.getInstance();
        await AccountAuthProviderStore(
          prefs,
        ).write('acc-cloud-a', AccountAuthProvider.emailPassword);
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);
        when(
          () => auth.signInToAccountWithEmail(
            'acc-cloud-a',
            targetEmail,
            'correct-password',
          ),
        ).thenAnswer((_) async {
          final user = _user(
            targetUid,
            targetEmail,
          ).copyWith(providers: const ['password']);
          when(() => auth.currentUser).thenReturn(user);
          return user;
        });

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'correct-password');
        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => auth.signInToAccountWithEmail(
            'acc-cloud-a',
            targetEmail,
            'correct-password',
          ),
        ).called(1);
        verifyNever(() => auth.pickGoogleAccount());
        final replaced = verify(() => router.replaceAll(captureAny())).captured;
        final routes = (replaced.last as List).cast<PageRouteInfo>();
        expect(routes.any((r) => r is AppShellRoute), isTrue);
      },
    );
  });

  // ── Cloud account instant switch: valid session (hasValidSession = true) ───
  //
  // When the live Firebase session already belongs to the tapped cloud account
  // (currentUser.uid == account.firebaseUid), the switch is "instant" — no
  // re-authentication is needed. The tap must:
  //   1. NOT call signInWithGoogle() or reauthWithGoogleSilently().
  //   2. Navigate to AppShellRoute (DB swap + session activation completes).
  //   3. NOT route to SignInRoute.
  //
  // iter9 finding: this path was untested; verifying it locks the invariant.
  group('cloud account instant switch (hasValidSession = true)', () {
    const cloudUid = 'fb-uid-cloud-instant';
    const cloudEmail = 'instant@test.cloud';

    Future<void> seedInstantCloudAccount() async {
      // This account's OWN named-app session is valid (DNI-520).
      when(() => auth.currentUser).thenReturn(_user(cloudUid, cloudEmail));
      when(
        () => auth.restoreSession('acc-cloud-instant'),
      ).thenAnswer((_) async => _user(cloudUid, cloudEmail));
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => auth.currentUser);
      when(
        () => auth.pickGoogleAccountSilently(),
      ).thenAnswer((_) async => null);

      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-cloud-instant',
          email: cloudEmail,
          displayName: 'Instant Cloud',
          tier: 'cloudBorn',
          dbFileName: 'user_acc_acc-cloud-instant.db',
          firebaseUid: const Value(cloudUid),
          createdAt: DateTime.utc(2026, 1, 3),
          lastUsedAt: DateTime.utc(2026, 1, 3),
        ),
      );
      await seedAccount(
        firestore,
        uid: cloudUid,
        email: cloudEmail,
        displayName: 'Instant Cloud',
      );
    }

    testWidgets('valid session → instant switch to AppShell, no re-auth called', (
      tester,
    ) async {
      await seedInstantCloudAccount();

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the cloud account tile.
      await tester.tap(find.text('Instant Cloud'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Instant switch: NO re-auth was triggered.
      verifyNever(() => auth.pickGoogleAccount());
      verifyNever(() => auth.pickGoogleAccountSilently());
      verifyNever(() => auth.signInToAccountWithGoogle(any(), any()));
      // Sign-out must never happen on an account switch.
      verifyNever(() => auth.signOut());

      // Navigated to AppShell, not SignIn.
      final replaced = verify(() => router.replaceAll(captureAny())).captured;
      expect(
        replaced,
        isNotEmpty,
        reason: 'instant switch must navigate to the app shell',
      );
      final routes = (replaced.last as List).cast<PageRouteInfo>();
      expect(
        routes.any((r) => r is AppShellRoute),
        isTrue,
        reason:
            'instant cloud switch (hasValidSession=true) must land on AppShellRoute',
      );
      expect(
        routes.any((r) => r is SignInRoute),
        isFalse,
        reason: 'instant cloud switch must NOT route to sign-in',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // DNI-520 AC-6: switching back and forth between a cloud account and an
    // anonymous (local) account keeps each account on its OWN named app —
    // the anonymous account's session never replaces the cloud one, so
    // returning to the cloud account is still an instant switch.
    testWidgets('cloud → anonymous → cloud: each account keeps its own '
        'named-app session; no sign-out, no re-auth', (tester) async {
      await seedInstantCloudAccount();
      when(() => auth.ensureAnonymousSession('acc-local')).thenAnswer(
        (_) async => const AppUser(
          uid: 'fb-uid-local',
          email: null,
          displayName: null,
          emailVerified: false,
          providers: [],
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      for (final tile in ['Instant Cloud', 'Local User', 'Instant Cloud']) {
        await tester.tap(find.text(tile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // The anonymous account got its named-app session exactly once (AC-2).
      verify(() => auth.ensureAnonymousSession('acc-local')).called(1);
      // The cloud account's own session was consulted, never replaced.
      verify(
        () => auth.restoreSession('acc-cloud-instant'),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(() => auth.ensureAnonymousSession('acc-cloud-instant'));
      verifyNever(() => auth.pickGoogleAccount());
      verifyNever(() => auth.pickGoogleAccountSilently());
      verifyNever(() => auth.signInToAccountWithGoogle(any(), any()));
      verifyNever(() => auth.signOut());

      // All three switches landed on the app shell.
      final replaced = verify(() => router.replaceAll(captureAny())).captured;
      expect(replaced, hasLength(3));
      for (final call in replaced) {
        expect(
          (call as List).cast<PageRouteInfo>().any((r) => r is AppShellRoute),
          isTrue,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
