// Regression test for AN-4:
// AccountPicker ordering / rapid-tap / back-stack defects.
//
// Root cause (ordering): the account list was sorted by lastUsedAt DESC,
// which changes every time you switch accounts — making card positions
// unpredictable on successive visits.
//
// Root cause (rapid-tap): _AccountTile._onTap had no re-entrancy guard;
// double-tap launched concurrent account switches.
//
// Fix (ordering): active account is pinned first (dbFileName match); remaining
// accounts sorted by dbFileName (stable alphabetical proxy for creation order).
// Fix (rapid-tap): _switching flag in _AccountTileState blocks concurrent taps;
// onTap is null while _switching is true.
//
// AUD-t-account-03 (Feathers seam): this suite previously exercised
// hand-copied replicas of the sort comparator and the tap guard, so it never
// touched account_picker_screen.dart at all — a regression that reintroduced
// either bug in the REAL code would have kept this suite green. It now pumps
// the real [AccountPickerScreen] / `_AccountTile` and drives both assertions
// through production code:
//   - Ordering: seeds real accounts via the device registry, overrides
//     [accountDbFileNameProvider] to select the "active" one, and asserts the
//     rendered tile order (top-to-bottom) produced by AccountPickerScreen.build.
//   - Tap guard: taps the real `_AccountTile`'s InkWell twice in quick
//     succession. The re-entrancy window is held open by a slow-resolving
//     fake [InternetConnectionChecker.hasConnection] — the first real await
//     point inside `_AccountTileState._onTap` for a cloud account with no
//     valid session — so the guard's `_switching` state is genuinely
//     in-flight (not a synthetic delay) when the second tap lands.
@Tags(['account', 'account_picker', 'an4'])
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
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
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

import '../../../../mocks/mock_repositories.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

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

/// AccountDbFileName that starts pinned at a given "active" account's DB
/// file — lets the ordering test control which seeded account is active
/// without touching real SharedPreferences/session-persistence plumbing.
class _StubAccountDbFileName extends AccountDbFileName {
  _StubAccountDbFileName(this._initial);
  final String _initial;

  @override
  String build() => _initial;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

DeviceAccountsCompanion _localAccount({
  required String accountId,
  required String email,
  required String displayName,
  required String dbFileName,
  required DateTime lastUsedAt,
}) => DeviceAccountsCompanion.insert(
  accountId: accountId,
  email: email,
  displayName: displayName,
  tier: 'localBorn',
  dbFileName: dbFileName,
  createdAt: lastUsedAt,
  lastUsedAt: lastUsedAt,
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
  createdAt: DateTime.utc(2026),
  lastUsedAt: DateTime.utc(2026),
);

Future<void> _seedCloudUserDbRow(
  UserDatabase userDb, {
  required String email,
  required String displayName,
  required String firebaseUid,
}) async {
  final now = DateTime.utc(2026);
  await userDb
      .into(userDb.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'cloudBorn',
          firebaseUid: Value(firebaseUid),
          displayName: displayName,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

// ── App wrapper ──────────────────────────────────────────────────────────────

Widget _buildApp({
  required DeviceRegistryDatabase registry,
  required UserDatabase userDb,
  required MockAuthRepository auth,
  required _MockStackRouter router,
  required String activeDbFileName,
  InternetConnectionChecker? connectivity,
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      userDatabaseProvider.overrideWith((ref) => userDb),
      syncOrchestratorProvider.overrideWithValue(null),
      accountDbFileNameProvider.overrideWith(
        () => _StubAccountDbFileName(activeDbFileName),
      ),
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
  late MockAuthRepository auth;
  late _MockStackRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    userDb = UserDatabase(NativeDatabase.memory());
    auth = MockAuthRepository();
    router = _MockStackRouter();

    when(() => auth.currentUser).thenReturn(null);
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

  // ── Ordering ───────────────────────────────────────────────────────────────

  testWidgets('AN-4: active account is pinned first through the real '
      'AccountPickerScreen.build sort, remaining accounts alphabetical by '
      'dbFileName — even when a non-active account was most recently used', (
    tester,
  ) async {
    // lastUsedAt intentionally makes 'Alpha' the most-recently-used
    // account while 'Zeta' (alphabetically last) is the ACTIVE one. The
    // pre-AN-4 bug sorted by lastUsedAt DESC, which would have put Alpha
    // first; the fix must pin Zeta first regardless.
    await registry.addAccount(
      _localAccount(
        accountId: 'acc-z',
        email: 'zeta@test.local',
        displayName: 'Zeta',
        dbFileName: 'user_acc_z.db',
        lastUsedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await registry.addAccount(
      _localAccount(
        accountId: 'acc-a',
        email: 'alpha@test.local',
        displayName: 'Alpha',
        dbFileName: 'user_acc_a.db',
        lastUsedAt: DateTime.utc(2026, 1, 3), // most recently used
      ),
    );
    await registry.addAccount(
      _localAccount(
        accountId: 'acc-m',
        email: 'mike@test.local',
        displayName: 'Mike',
        dbFileName: 'user_acc_m.db',
        lastUsedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        registry: registry,
        userDb: userDb,
        auth: auth,
        router: router,
        activeDbFileName: 'user_acc_z.db',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Zeta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Mike'), findsOneWidget);

    final zetaY = tester.getTopLeft(find.text('Zeta')).dy;
    final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
    final mikeY = tester.getTopLeft(find.text('Mike')).dy;

    expect(
      zetaY,
      lessThan(alphaY),
      reason:
          'AN-4: the active account (Zeta) must render first even though '
          'Alpha is both alphabetically earlier and more recently used',
    );
    expect(
      zetaY,
      lessThan(mikeY),
      reason: 'AN-4: the active account must render before Mike too',
    );
    expect(
      alphaY,
      lessThan(mikeY),
      reason:
          'AN-4: non-active accounts fall back to alphabetical dbFileName '
          'order (Alpha before Mike), NOT lastUsedAt order',
    );
  });

  // ── Tap guard ─────────────────────────────────────────────────────────────

  testWidgets(
    'AN-4: double-tapping a real _AccountTile drops the second tap while the '
    'first switch is genuinely in flight',
    (tester) async {
      await registry.addAccount(_cloudAccount(firebaseUid: 'fb-uid-1'));
      await _seedCloudUserDbRow(
        userDb,
        email: 'cloud@example.test',
        displayName: 'Cloud User',
        firebaseUid: 'fb-uid-1',
      );

      // No live Firebase session -> hasValidSession == false -> _onTap's
      // first await is `internetConnectionCheckerProvider.hasConnection`.
      // Hold it open with an uncompleted Completer so `_switching` is
      // genuinely true (not a synthetic timer) when the 2nd tap arrives.
      when(() => auth.currentUser).thenReturn(null);
      final checker = _MockInternetConnectionChecker();
      final gate = Completer<bool>();
      when(() => checker.hasConnection).thenAnswer((_) => gate.future);

      await tester.pumpWidget(
        _buildApp(
          registry: registry,
          userDb: userDb,
          auth: auth,
          router: router,
          activeDbFileName: 'learning_tracker',
          connectivity: checker,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cloud User'), findsOneWidget);

      // First tap: starts the switch; _switching flips true synchronously
      // (before the connectivity await), then the real _onTap suspends on
      // `checker.hasConnection`.
      await tester.tap(find.text('Cloud User'));
      await tester.pump();

      // Exactly one real switch attempt has reached the connectivity check.
      verify(() => checker.hasConnection).called(1);

      // Second tap while the guard is active: _AccountTile's InkWell.onTap
      // is null (guarded), so the tap has nothing to hit.
      await tester.tap(find.text('Cloud User'), warnIfMissed: false);
      await tester.pump();

      // REGRESSION GUARD: the dropped tap must NOT have started a second
      // switch attempt — no NEW call into the real _onTap's connectivity
      // check since the first `verify` above (which already consumed that
      // one matching invocation).
      verifyNever(() => checker.hasConnection);

      // Release the first switch (offline -> local-data activation path).
      gate.complete(false);
      await tester.pumpAndSettle();

      // Exactly one navigation occurred, from the single switch that ran.
      final calls = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(
        calls,
        hasLength(1),
        reason:
            'AN-4: the dropped second tap must never trigger a second '
            'account switch / navigation',
      );
      final routes = (calls.single as List).cast<PageRouteInfo>();
      expect(routes.any((r) => r is AppShellRoute), isTrue);
    },
  );

  testWidgets(
    'AN-4: after a real switch completes, a subsequent tap on the same '
    'tile is accepted (guard resets)',
    (tester) async {
      await registry.addAccount(_cloudAccount(firebaseUid: 'fb-uid-1'));
      await _seedCloudUserDbRow(
        userDb,
        email: 'cloud@example.test',
        displayName: 'Cloud User',
        firebaseUid: 'fb-uid-1',
      );

      when(() => auth.currentUser).thenReturn(null);
      final checker = _MockInternetConnectionChecker();
      when(() => checker.hasConnection).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _buildApp(
          registry: registry,
          userDb: userDb,
          auth: auth,
          router: router,
          activeDbFileName: 'learning_tracker',
          connectivity: checker,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // First tap — completes fully (guard sets then resets).
      await tester.tap(find.text('Cloud User'));
      await tester.pumpAndSettle();

      // Second tap, after the guard has reset — must be accepted and run
      // another real switch.
      await tester.tap(find.text('Cloud User'));
      await tester.pumpAndSettle();

      verify(() => checker.hasConnection).called(2);
      final calls = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(
        calls,
        hasLength(2),
        reason:
            'AN-4: guard must reset after the first switch completes, '
            'allowing a genuine second switch',
      );
    },
  );
}
