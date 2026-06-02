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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

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
  late UserDatabase userDb;
  late _MockAuthRepository auth;
  late _MockStackRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    userDb = UserDatabase(NativeDatabase.memory());
    auth = _MockAuthRepository();
    router = _MockStackRouter();

    when(() => auth.currentUser).thenReturn(null);
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => router.replaceAll(any())).thenAnswer((_) async {});

    // One saved LOCAL account in the device registry…
    await registry.addAccount(
      DeviceAccountsCompanion.insert(
        accountId: 'acc-local',
        email: 'local@test.local',
        displayName: 'Local User',
        tier: 'localBorn',
        dbFileName: 'user_acc_acc-local.db',
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    // …with a matching local-born account row in the user DB so the switch
    // (findLocalBornByEmail) resolves and completes through to AppShell.
    await userDb
        .into(userDb.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'local@test.local',
            tier: 'localBorn',
            displayName: 'Local User',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await registry.close();
    await userDb.close();
  });

  Widget buildApp({InternetConnectionChecker? connectivity}) => ProviderScope(
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      userDatabaseProvider.overrideWith((ref) => userDb),
      // No real Firestore orchestrator in widget tests — the switch path reads
      // it to kick a best-effort launch pull; null is the not-cloud/unavailable
      // case and keeps the test offline.
      syncOrchestratorProvider.overrideWithValue(null),
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
      await tester.pumpWidget(buildApp());
      await tester.pump(); // resolve the getAllAccounts() FutureBuilder
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Local User'), findsOneWidget);

      await tester.tap(find.text('Local User'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // THE invariant: switching never signs out.
      verifyNever(() => auth.signOut());
      // Local-born accounts never touch Firebase — no re-auth on switch.
      verifyNever(() => auth.signInWithGoogle());

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
  // The device has ONE Firebase currentUser slot. Switching to cloud account A
  // while Firebase is still signed in as account B leaves A's Firestore
  // reads/writes permission-denied. Tapping a cloud account whose firebaseUid
  // != the live uid must re-authenticate (signInWithGoogle → native picker) to
  // THAT account's identity, verify the uid matches, then activate.
  group('cloud-account switch re-authenticates Firebase', () {
    const targetUid = 'fb-uid-cloud-A';
    const targetEmail = 'cloud-a@test.cloud';

    Future<void> seedCloudAccount() async {
      // Live session belongs to a DIFFERENT account (B) — mismatch.
      when(
        () => auth.currentUser,
      ).thenReturn(_user('fb-uid-B', 'b@test.cloud'));
      when(() => auth.signOut()).thenAnswer((_) async {});
      // authStateProvider._init() reloads the live user on first build.
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => auth.currentUser);

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
      // Matching cloud-born profile row so _activateCloudAccountFromLocalData
      // resolves a profile and completes the switch.
      await userDb
          .into(userDb.accounts)
          .insert(
            AccountsCompanion.insert(
              email: targetEmail,
              tier: 'cloudBorn',
              displayName: 'Cloud A',
              firebaseUid: const Value(targetUid),
              createdAt: DateTime.utc(2026, 1, 2),
              updatedAt: DateTime.utc(2026, 1, 2),
            ),
          );
    }

    testWidgets(
      'uid mismatch + re-auth success → signInWithGoogle + activate AppShell',
      (tester) async {
        await seedCloudAccount();
        final online = _MockInternetConnectionChecker();
        when(() => online.hasConnection).thenAnswer((_) async => true);

        // After signInWithGoogle, the live session becomes the TARGET account.
        when(() => auth.signInWithGoogle()).thenAnswer((_) async {
          when(
            () => auth.currentUser,
          ).thenReturn(_user(targetUid, targetEmail));
        });

        await tester.pumpWidget(buildApp(connectivity: online));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Cloud A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Re-auth was triggered to align the live identity.
        verify(() => auth.signInWithGoogle()).called(1);
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

      // User picked the WRONG Google account — live uid != target uid.
      when(() => auth.signInWithGoogle()).thenAnswer((_) async {
        when(
          () => auth.currentUser,
        ).thenReturn(_user('fb-uid-WRONG', 'wrong@test.cloud'));
      });

      await tester.pumpWidget(buildApp(connectivity: online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => auth.signInWithGoogle()).called(1);
      // Wrong identity → the mis-picked session is signed out and the switch
      // is aborted: NO navigation to AppShell.
      verify(() => auth.signOut()).called(1);
      verifyNever(() => router.replaceAll(any()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('re-auth user-cancel → graceful local fallback activation', (
      tester,
    ) async {
      await seedCloudAccount();
      final online = _MockInternetConnectionChecker();
      when(() => online.hasConnection).thenAnswer((_) async => true);

      // User cancels the native account picker.
      when(() => auth.signInWithGoogle()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      await tester.pumpWidget(buildApp(connectivity: online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cloud A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => auth.signInWithGoogle()).called(1);
      // Cancel falls back to local activation (offline-first), still lands on
      // the shell; the identity guard surfaces "sign in to back up".
      final replaced = verify(() => router.replaceAll(captureAny())).captured;
      final routes = (replaced.last as List).cast<PageRouteInfo>();
      expect(routes.any((r) => r is AppShellRoute), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
