// Regression test for ACCTPICK-03 / SI-04 (loop-iter1):
//
// When a cloud account tile is tapped offline (stale session) and the
// local SQLite DB does NOT contain a matching profile row for that account,
// `_activateCloudAccountFromLocalData` was silently returning without any
// user feedback — the picker screen stayed visible with no indication of the
// failure. The user had no way to know what went wrong or what to do next.
//
// Fix: surface a SnackBar with `l10n.authLocalDataMissing` so the user is
// told "local data is missing, connect to restore it" rather than being
// left in a silent, unresolvable state.
//
// Similarly, when a local-born account tile is tapped and the local profile
// row is absent (DB deleted / corrupted), the same silent-return bug applied.
//
// Covered cases:
//   C1 — cloud account, offline, NO local profile row → SnackBar shown,
//        router.replaceAll NOT called (no navigation to AppShell).
//   C2 — local-born account, NO local profile row → SnackBar shown,
//        router.replaceAll NOT called.

@Tags(['needs_flutter', 'account', 'multi_account'])
library;

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
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
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

class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _StubSelectedProfileId extends SelectedProfileId {
  @override
  int? build() => null;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

final _kNow = DateTime.utc(2026, 1, 1);

/// A cloud account row in the device registry (NO matching row in userDb).
DeviceAccountsCompanion _cloudAccountEntry({
  String accountId = 'acc-cloud-missing',
  String email = 'cloud-missing@example.test',
  String displayName = 'Cloud Missing',
  String dbFileName = 'user_acc_cloud_missing.db',
  String firebaseUid = 'fb-uid-missing',
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

/// A local-born account row in the device registry (NO matching row in userDb).
DeviceAccountsCompanion _localAccountEntry({
  String accountId = 'acc-local-missing',
  String email = 'local-missing@example.test',
  String displayName = 'Local Missing',
  String dbFileName = 'user_acc_local_missing.db',
}) => DeviceAccountsCompanion.insert(
  accountId: accountId,
  email: email,
  displayName: displayName,
  tier: 'localBorn',
  dbFileName: dbFileName,
  createdAt: _kNow,
  lastUsedAt: _kNow,
);

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget _buildApp({
  required DeviceRegistryDatabase registry,
  required UserDatabase userDb,
  required _MockAuthRepository auth,
  required _MockStackRouter router,
  InternetConnectionChecker? connectivity,
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      userDatabaseProvider.overrideWith((ref) => userDb),
      syncOrchestratorProvider.overrideWithValue(null),
      if (connectivity != null)
        internetConnectionCheckerProvider.overrideWithValue(connectivity),
      authStateProvider.overrideWith(
        () => _StubAuthStateNotifier(const AuthState.signedOut()),
      ),
      selectedProfileIdProvider.overrideWith(() => _StubSelectedProfileId()),
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
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late DeviceRegistryDatabase registry;
  late UserDatabase userDb;
  late _MockAuthRepository auth;
  late _MockStackRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    // INTENTIONALLY empty userDb — no profile rows for the accounts below.
    userDb = UserDatabase(NativeDatabase.memory());
    auth = _MockAuthRepository();
    router = _MockStackRouter();

    when(() => auth.currentUser).thenReturn(null);
    // AUD-account-18: _AccountTile now watches the reactive auth-state stream
    // (instead of ref.read-ing auth.currentUser) to compute hasValidSession.
    // Mirror whatever auth.currentUser is stubbed to at subscribe time so the
    // reactive value matches the synchronous one the rest of this suite sets.
    when(
      () => auth.onAuthStateChanged(),
    ).thenAnswer((_) => Stream.value(auth.currentUser));
    when(() => router.push(any<PageRouteInfo>())).thenAnswer((_) async => null);
    when(
      () => router.replaceAll(any<List<PageRouteInfo>>()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await registry.close();
    await userDb.close();
  });

  // ── C1: cloud account, offline, NO local profile ──────────────────────────

  testWidgets('C1 — cloud account offline, local DB missing profile: '
      'shows authLocalDataMissing SnackBar, does NOT navigate to AppShell', (
    tester,
  ) async {
    // Seed the cloud account in the device registry.
    await registry.addAccount(_cloudAccountEntry());

    // Simulate offline — no live Firebase session (stale), no internet.
    final offline = _MockInternetConnectionChecker();
    when(() => offline.hasConnection).thenAnswer((_) async => false);
    // No live Firebase session → hasValidSession == false → offline path.
    when(() => auth.currentUser).thenReturn(null);

    await tester.pumpWidget(
      _buildApp(
        registry: registry,
        userDb: userDb,
        auth: auth,
        router: router,
        connectivity: offline,
      ),
    );
    await tester.pump(); // resolve FutureBuilder

    // The account tile is rendered.
    expect(find.text('Cloud Missing'), findsOneWidget);

    // Tap the tile → triggers _activateCloudAccountFromLocalData offline path.
    await tester.tap(find.text('Cloud Missing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // REGRESSION GUARD: A SnackBar with the "local data missing" message
    // must be shown — the user is told why nothing happened.
    expect(
      find.text(
        'This account\'s local data is missing. '
        'Connect to the internet to restore it.',
      ),
      findsOneWidget,
      reason:
          'Silent fail: no error shown when cloud local data is missing '
          '(ACCTPICK-03)',
    );

    // No navigation away from the picker — the user remains on the picker
    // and can choose another account or connect to the internet.
    verifyNever(() => router.replaceAll(any()));
  });

  // ── C2: local-born account, NO local profile ──────────────────────────────

  testWidgets('C2 — local-born account, local DB missing profile: '
      'shows authLocalDataMissing SnackBar, does NOT navigate to AppShell', (
    tester,
  ) async {
    // Seed the local account in the device registry.
    await registry.addAccount(_localAccountEntry());

    // No internet check needed for local-born path (no network probe).
    when(() => auth.currentUser).thenReturn(null);

    await tester.pumpWidget(
      _buildApp(registry: registry, userDb: userDb, auth: auth, router: router),
    );
    await tester.pump(); // resolve FutureBuilder

    // The account tile is rendered.
    expect(find.text('Local Missing'), findsOneWidget);

    // Tap the tile → triggers _activateLocalAccountFromLocalData.
    await tester.tap(find.text('Local Missing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // REGRESSION GUARD: A SnackBar with the "local data missing" message
    // must be shown.
    expect(
      find.text(
        'This account\'s local data is missing. '
        'Connect to the internet to restore it.',
      ),
      findsOneWidget,
      reason:
          'Silent fail: no error shown when local-born local data is missing',
    );

    // No navigation away from the picker.
    verifyNever(() => router.replaceAll(any()));
  });
}
