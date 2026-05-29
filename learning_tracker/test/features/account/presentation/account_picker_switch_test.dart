// AccountPicker — switching accounts must NEVER sign out (DEC-34).
//
// Locks the behaviour Daniel asked about: tapping a saved account switches in
// place (swap DB + session + reload to AppShell) and keeps you signed in. The
// picker must never call AuthRepository.signOut() and must not bounce a
// local/valid account to the sign-in screen.

@Tags(['account', 'multi_account'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

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

  Widget buildApp() => ProviderScope(
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      userDatabaseProvider.overrideWith((ref) => userDb),
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
}
