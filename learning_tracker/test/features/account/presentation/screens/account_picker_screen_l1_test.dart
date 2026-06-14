// L1 widget tests for AccountPickerScreen
//
// Verifies:
//   1. Loading state shows CircularProgressIndicator while FutureBuilder resolves.
//   2. Single local-born account renders display name, email, LOCAL ACCOUNT badge.
//   3. Single cloud-born account with valid session renders CLOUD ACCOUNT badge +
//      chevron icon.
//   4. Cloud account with NO valid session renders SIGN IN AGAIN badge + warning icon.
//   5. Multiple accounts are all listed (two accounts).
//   6. Account count < kMaxDeviceAccounts shows "Add another account" button.
//   7. Account count == kMaxDeviceAccounts shows max-accounts message (no add button).
//   8. Select local-born account — DEC-34: signOut is NEVER called; router pushes
//      AppShellRoute (no-sign-out switch flow).
//   9. Select cloud-born account with valid session — DEC-34: signOut NOT called;
//      router pushes AppShellRoute.
//  10. Swipe-to-remove (cloud): confirm dialog shows "Remove from device?" title.
//  11. Swipe-to-remove (local): confirm dialog shows "Delete account?" title.
//  12. Cancel dismiss dialog — item is still rendered (not removed).
//  13. Privacy footer text is always rendered.
//  14. Hebrew-locale smoke: screen renders without crashing, title in Hebrew.
//
// BUG LOG: None.

@Tags(['needs_flutter', 'account', 'multi_account'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show SelectedProfileId, selectedProfileIdProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// AuthStateNotifier that starts at a known state without touching Firebase.
class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

/// SelectedProfileId that stays at null without touching the sync facade.
class _StubSelectedProfileId extends SelectedProfileId {
  @override
  int? build() => null;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

final _kNow = DateTime.utc(2026, 1, 1);

DeviceAccountsCompanion _localAccount({
  String accountId = 'acc-local-1',
  String email = 'local@example.test',
  String displayName = 'Local Learner',
  String dbFileName = 'user_acc_local1.db',
}) => DeviceAccountsCompanion.insert(
  accountId: accountId,
  email: email,
  displayName: displayName,
  tier: 'localBorn',
  dbFileName: dbFileName,
  createdAt: _kNow,
  lastUsedAt: _kNow,
);

DeviceAccountsCompanion _cloudAccount({
  String accountId = 'acc-cloud-1',
  String email = 'cloud@example.test',
  String displayName = 'Cloud User',
  String dbFileName = 'user_acc_cloud1.db',
  String firebaseUid = 'fb-uid-1',
}) => DeviceAccountsCompanion.insert(
  accountId: accountId,
  email: email,
  displayName: displayName,
  tier: 'cloudBorn',
  firebaseUid: Value(firebaseUid),
  dbFileName: dbFileName,
  createdAt: _kNow,
  lastUsedAt: _kNow,
);

AppUser _fakeCloudUser({String uid = 'fb-uid-1'}) => AppUser(
  uid: uid,
  email: 'cloud@example.test',
  displayName: 'Cloud User',
  emailVerified: true,
  providers: const ['password'],
);

// ── Test fixture ─────────────────────────────────────────────────────────────

class _Fixture {
  _Fixture({
    required this.registry,
    required this.userDb,
    required this.auth,
    required this.router,
  });

  final DeviceRegistryDatabase registry;
  final UserDatabase userDb;
  final _MockAuthRepository auth;
  final _MockStackRouter router;

  /// Seed a matching local-born account row in userDb so that
  /// findLocalBornByEmail resolves during the switch flow.
  Future<void> seedLocalUserDbRow({
    String email = 'local@example.test',
    String displayName = 'Local Learner',
  }) async {
    await userDb
        .into(userDb.accounts)
        .insert(
          AccountsCompanion.insert(
            email: email,
            tier: 'localBorn',
            displayName: displayName,
            createdAt: _kNow,
            updatedAt: _kNow,
          ),
        );
  }

  /// Seed a matching cloud-born account row in userDb so that
  /// findCloudBornByFirebaseUid resolves during the switch flow.
  Future<void> seedCloudUserDbRow({
    String email = 'cloud@example.test',
    String displayName = 'Cloud User',
    String firebaseUid = 'fb-uid-1',
  }) async {
    await userDb
        .into(userDb.accounts)
        .insert(
          AccountsCompanion.insert(
            email: email,
            tier: 'cloudBorn',
            firebaseUid: Value(firebaseUid),
            displayName: displayName,
            createdAt: _kNow,
            updatedAt: _kNow,
          ),
        );
  }

  Widget buildSubject({
    Locale locale = const Locale('en'),
    InternetConnectionChecker? connectivityChecker,
  }) {
    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        deviceRegistryProvider.overrideWithValue(registry),
        authRepositoryProvider.overrideWithValue(auth),
        userDatabaseProvider.overrideWith((ref) => userDb),
        // No real Firestore orchestrator in widget tests — the cloud-switch
        // path reads it to kick a best-effort launch pull.
        syncOrchestratorProvider.overrideWithValue(null),
        if (connectivityChecker != null)
          internetConnectionCheckerProvider.overrideWithValue(
            connectivityChecker,
          ),
        // Provide a neutral AuthState so AuthStateNotifier.build() doesn't
        // call authRepo.reloadCurrentUser() (which would hit Firebase).
        // Use overrideWith (not overrideWithValue) so .notifier access works.
        authStateProvider.overrideWith(
          () => _StubAuthStateNotifier(const AuthState.signedOut()),
        ),
        // Prevent selectedProfileIdProvider from reaching the sync facade.
        // Use overrideWith so .notifier.clear() works during account switch.
        selectedProfileIdProvider.overrideWith(() => _StubSelectedProfileId()),
      ],
      child: MaterialApp(
        locale: locale,
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
  }
}

Future<_Fixture> _buildFixture() async {
  SharedPreferences.setMockInitialValues({});
  final registry = DeviceRegistryDatabase(NativeDatabase.memory());
  final userDb = UserDatabase(NativeDatabase.memory());
  final auth = _MockAuthRepository();
  final router = _MockStackRouter();

  when(() => auth.currentUser).thenReturn(null);
  when(() => router.push(any<PageRouteInfo>())).thenAnswer((_) async => null);
  when(
    () => router.replaceAll(any<List<PageRouteInfo>>()),
  ).thenAnswer((_) async {});

  return _Fixture(
    registry: registry,
    userDb: userDb,
    auth: auth,
    router: router,
  );
}

Future<void> _tearDown(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
  await fixture.registry.close();
  await fixture.userDb.close();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // ── 1. Loading state ────────────────────────────────────────────────────────

  testWidgets(
    '1. shows CircularProgressIndicator while getAllAccounts is pending',
    (tester) async {
      final fixture = await _buildFixture();
      final completer = Completer<List<DeviceAccount>>();
      final mockRegistry = _PendingRegistry(completer.future);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            deviceRegistryProvider.overrideWithValue(mockRegistry),
            authRepositoryProvider.overrideWithValue(fixture.auth),
            userDatabaseProvider.overrideWith((ref) => fixture.userDb),
            authStateProvider.overrideWith(
              () => _StubAuthStateNotifier(const AuthState.signedOut()),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _StubSelectedProfileId(),
            ),
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
              controller: fixture.router,
              stateHash: 0,
              child: const AccountPickerScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pump(const Duration(seconds: 1));

      await _tearDown(tester, fixture);
      await mockRegistry.close();
    },
  );

  // ── 2. Single local-born account ────────────────────────────────────────────

  testWidgets(
    '2. single local-born account shows display name, email, LOCAL ACCOUNT badge',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_localAccount());

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Title and subtitle
      expect(find.text('Choose an Account'), findsOneWidget);
      expect(find.text('Select an account to continue'), findsOneWidget);

      // Account tile content
      expect(find.text('Local Learner'), findsOneWidget);
      expect(find.text('local@example.test'), findsOneWidget);

      // Tier badge for local-born
      expect(find.text('LOCAL ACCOUNT'), findsOneWidget);

      // Lock icon for local-born (no Firebase session)
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      await _tearDown(tester, fixture);
    },
  );

  // ── 3. Cloud account with valid session ──────────────────────────────────────

  testWidgets(
    '3. cloud account with valid session shows CLOUD ACCOUNT badge + chevron',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_cloudAccount());

      // authRepo.currentUser returns the matching Firebase user
      when(
        () => fixture.auth.currentUser,
      ).thenReturn(_fakeCloudUser(uid: 'fb-uid-1'));

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cloud User'), findsOneWidget);
      expect(find.text('cloud@example.test'), findsOneWidget);

      // Badge for active cloud session
      expect(find.text('CLOUD ACCOUNT'), findsOneWidget);

      // Chevron icon (active cloud session)
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // No sign-in-again badge
      expect(find.text('SIGN IN AGAIN'), findsNothing);

      await _tearDown(tester, fixture);
    },
  );

  // ── 4. Cloud account with NO valid session ───────────────────────────────────

  testWidgets(
    '4. cloud account with no valid session shows SIGN IN AGAIN badge + warning icon',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_cloudAccount(firebaseUid: 'fb-uid-1'));

      // currentUser is null → no valid session
      when(() => fixture.auth.currentUser).thenReturn(null);

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SIGN IN AGAIN'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.text('CLOUD ACCOUNT'), findsNothing);

      await _tearDown(tester, fixture);
    },
  );

  // ── 5. Multiple accounts listed ──────────────────────────────────────────────

  testWidgets('5. two accounts — both names rendered', (tester) async {
    final fixture = await _buildFixture();
    await fixture.registry.addAccount(
      _localAccount(
        accountId: 'acc-a',
        email: 'alice@test.local',
        displayName: 'Alice',
        dbFileName: 'user_acc_a.db',
      ),
    );
    await fixture.registry.addAccount(
      _localAccount(
        accountId: 'acc-b',
        email: 'bob@test.local',
        displayName: 'Bob',
        dbFileName: 'user_acc_b.db',
      ),
    );

    await tester.pumpWidget(fixture.buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Two LOCAL ACCOUNT badges
    expect(find.text('LOCAL ACCOUNT'), findsNWidgets(2));

    await _tearDown(tester, fixture);
  });

  // ── 6. Add-account button visible when below kMaxDeviceAccounts ──────────────

  testWidgets(
    '6. add-another button shown when account count < kMaxDeviceAccounts',
    (tester) async {
      final fixture = await _buildFixture();
      // Seed 2 accounts — below the limit of 5
      await fixture.registry.addAccount(
        _localAccount(
          accountId: 'acc-1',
          email: 'a1@test.local',
          dbFileName: 'f1.db',
        ),
      );
      await fixture.registry.addAccount(
        _localAccount(
          accountId: 'acc-2',
          email: 'a2@test.local',
          displayName: 'User 2',
          dbFileName: 'f2.db',
        ),
      );

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The add-another button text includes "Add another account"
      expect(find.textContaining('Add another account'), findsOneWidget);

      // The remaining slots = kMaxDeviceAccounts - 2 = 3
      expect(find.textContaining('3 slots remaining'), findsOneWidget);

      // Max-accounts message must NOT appear
      expect(
        find.textContaining(
          'Maximum $kMaxDeviceAccounts device accounts reached',
        ),
        findsNothing,
      );

      await _tearDown(tester, fixture);
    },
  );

  // ── 7. Max-accounts message when at limit ────────────────────────────────────

  testWidgets(
    '7. max-accounts message shown when account count == kMaxDeviceAccounts',
    (tester) async {
      final fixture = await _buildFixture();
      for (var i = 0; i < kMaxDeviceAccounts; i++) {
        await fixture.registry.addAccount(
          _localAccount(
            accountId: 'acc-$i',
            email: 'user$i@test.local',
            displayName: 'User $i',
            dbFileName: 'user_acc_$i.db',
          ),
        );
      }

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Max message rendered
      expect(
        find.textContaining(
          'Maximum $kMaxDeviceAccounts device accounts reached',
        ),
        findsOneWidget,
      );

      // Add button NOT rendered
      expect(find.textContaining('Add another account'), findsNothing);

      await _tearDown(tester, fixture);
    },
  );

  // ── 8. Select local-born account — DEC-34 no-sign-out switch ─────────────────

  testWidgets(
    '8. DEC-34: tapping local-born account switches to AppShell WITHOUT calling signOut',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_localAccount());
      await fixture.seedLocalUserDbRow();

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Local Learner'), findsOneWidget);

      await tester.tap(find.text('Local Learner'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // THE invariant: no sign-out during account switch (DEC-34)
      verifyNever(() => fixture.auth.signOut());

      // Navigated to AppShellRoute
      final calls = verify(
        () => fixture.router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(calls, isNotEmpty);
      final routes = (calls.last as List).cast<PageRouteInfo>();
      expect(
        routes.any((r) => r is AppShellRoute),
        isTrue,
        reason: 'local-born switch must navigate to AppShellRoute',
      );
      expect(
        routes.any((r) => r is SignInRoute),
        isFalse,
        reason: 'local-born switch must never navigate to SignInRoute',
      );

      await _tearDown(tester, fixture);
    },
  );

  // ── 9. Select cloud-born account with valid session — DEC-34 ─────────────────

  testWidgets(
    '9. DEC-34: tapping cloud account (valid session) switches to AppShell '
    'WITHOUT calling signOut',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_cloudAccount());
      await fixture.seedCloudUserDbRow();

      // Valid session — Firebase currentUser matches the registry uid.
      when(
        () => fixture.auth.currentUser,
      ).thenReturn(_fakeCloudUser(uid: 'fb-uid-1'));

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cloud User'), findsOneWidget);

      await tester.tap(find.text('Cloud User'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // THE invariant: no sign-out during account switch (DEC-34)
      verifyNever(() => fixture.auth.signOut());

      final calls = verify(
        () => fixture.router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(calls, isNotEmpty);
      final routes = (calls.last as List).cast<PageRouteInfo>();
      expect(
        routes.any((r) => r is AppShellRoute),
        isTrue,
        reason: 'cloud-born valid-session switch must land on AppShellRoute',
      );
      expect(
        routes.any((r) => r is SignInRoute),
        isFalse,
        reason: 'cloud-born valid-session switch must never route to sign-in',
      );

      await _tearDown(tester, fixture);
    },
  );

  // ── 10. Swipe-to-remove cloud account — confirm dialog title ─────────────────

  testWidgets('10. swiping cloud account shows "Remove from device?" dialog', (
    tester,
  ) async {
    final fixture = await _buildFixture();
    await fixture.registry.addAccount(_cloudAccount());

    await tester.pumpWidget(fixture.buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Swipe the cloud account tile end-to-start to trigger dismiss
    await tester.drag(find.text('Cloud User'), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The _confirmDismiss callback shows a dialog
    expect(find.text('Remove from device?'), findsOneWidget);
    expect(
      find.text('Your cloud data is safe — you can sign back in anytime.'),
      findsOneWidget,
    );

    await _tearDown(tester, fixture);
  });

  // ── 11. Swipe-to-remove local account — confirm dialog title ─────────────────

  testWidgets('11. swiping local account shows "Delete account?" dialog', (
    tester,
  ) async {
    final fixture = await _buildFixture();
    await fixture.registry.addAccount(_localAccount());

    await tester.pumpWidget(fixture.buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.drag(find.text('Local Learner'), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete account?'), findsOneWidget);
    expect(
      find.text(
        'All learning data will be permanently lost. This cannot be undone.',
      ),
      findsOneWidget,
    );

    await _tearDown(tester, fixture);
  });

  // ── 12. Cancel dismiss — item stays ──────────────────────────────────────────

  testWidgets(
    '12. cancelling the dismiss dialog keeps the account tile visible',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_localAccount());

      await tester.pumpWidget(fixture.buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Swipe
      await tester.drag(find.text('Local Learner'), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete account?'), findsOneWidget);

      // Tap "Cancel"
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tile remains visible — dismissal was cancelled
      expect(find.text('Local Learner'), findsOneWidget);

      await _tearDown(tester, fixture);
    },
  );

  // ── 13. Privacy footer always rendered ───────────────────────────────────────

  testWidgets('13. privacy footer text is always visible', (tester) async {
    final fixture = await _buildFixture();
    await fixture.registry.addAccount(_localAccount());

    await tester.pumpWidget(fixture.buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Manage your privacy and security in Settings'),
      findsOneWidget,
    );

    await _tearDown(tester, fixture);
  });

  // ── 14. Hebrew-locale smoke ───────────────────────────────────────────────────

  testWidgets('14. Hebrew locale: screen renders, title in Hebrew', (
    tester,
  ) async {
    final fixture = await _buildFixture();
    await fixture.registry.addAccount(
      _localAccount(displayName: 'בני', email: 'beni@example.test'),
    );

    await tester.pumpWidget(fixture.buildSubject(locale: const Locale('he')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Hebrew title rendered
    expect(find.text('בחירת חשבון'), findsOneWidget);

    // Hebrew badge for local-born
    expect(find.text('חשבון מקומי'), findsOneWidget);

    // Account name still shows
    expect(find.text('בני'), findsOneWidget);

    await _tearDown(tester, fixture);
  });

  // ── 15. Offline tap of expired-session cloud tile restores locally ──────────
  //
  // Offline-first regression: tapping a "SIGN IN AGAIN" (expired-session) cloud
  // tile WHILE OFFLINE must restore the local data and land on AppShellRoute —
  // never push SignInRoute (which would gate the user behind a network sign-in
  // they cannot complete offline).

  testWidgets(
    '15. tapping an expired-session cloud tile WHILE OFFLINE restores local '
    'data and routes to AppShell (never SignInRoute)',
    (tester) async {
      final fixture = await _buildFixture();
      await fixture.registry.addAccount(_cloudAccount(firebaseUid: 'fb-uid-1'));
      // Seed the matching cloud-born profile row so the local restore resolves
      // a profile without any network call.
      await fixture.seedCloudUserDbRow(firebaseUid: 'fb-uid-1');

      // Expired session — Firebase currentUser is null → "SIGN IN AGAIN".
      when(() => fixture.auth.currentUser).thenReturn(null);

      // Offline.
      final checker = _MockInternetConnectionChecker();
      when(() => checker.hasConnection).thenAnswer((_) async => false);

      await tester.pumpWidget(
        fixture.buildSubject(connectivityChecker: checker),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SIGN IN AGAIN'), findsOneWidget);

      await tester.tap(find.text('Cloud User'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final calls = verify(
        () => fixture.router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(
        calls,
        isNotEmpty,
        reason: 'offline restore must navigate via replaceAll',
      );
      final routes = (calls.last as List).cast<PageRouteInfo>();
      expect(
        routes.any((r) => r is AppShellRoute),
        isTrue,
        reason: 'offline expired-session restore must land on AppShellRoute',
      );
      // The offline path must NOT push the network sign-in screen.
      verifyNever(() => fixture.router.push(any<PageRouteInfo>()));

      await _tearDown(tester, fixture);
    },
  );
}

// ── Fake DeviceRegistryDatabase for loading state test ───────────────────────

/// Extends [DeviceRegistryDatabase] and overrides [getAllAccounts] to return
/// a supplied future, letting us freeze the FutureBuilder in a loading state.
class _PendingRegistry extends DeviceRegistryDatabase {
  _PendingRegistry(this._future) : super(NativeDatabase.memory());

  final Future<List<DeviceAccount>> _future;

  @override
  Future<List<DeviceAccount>> getAllAccounts() => _future;
}
