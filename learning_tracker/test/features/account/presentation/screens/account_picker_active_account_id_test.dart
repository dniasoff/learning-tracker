// Red-demo coverage for wiring `activeAccountIdProvider`
// (`lib/data/firestore/active_account_providers.dart`) into the account
// picker's real call sites.
//
// Before this wiring, `ActiveAccountId.set(...)` was never called anywhere
// in production — `activeAccountIdProvider` stayed `null` for the whole app
// session regardless of what the picker did. These tests drive the SAME
// widget flows `account_picker_switch_test.dart` already locks (switch
// in place, never sign out) and additionally assert the account id itself
// now tracks reality: set on activation, cleared to `null` when the active
// account is removed from the device.

@Tags(['account', 'multi_account'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_repositories.dart';
import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockStackRouter extends Mock implements StackRouter {}

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
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    firestore = createFakeFirestore();
    auth = MockAuthRepository();
    router = _MockStackRouter();

    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.onAuthStateChanged(),
    ).thenAnswer((_) => Stream.value(auth.currentUser));
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => router.replaceAll(any())).thenAnswer((_) async {});

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

  Widget buildApp() {
    container = ProviderContainer(
      overrides: [
        deviceRegistryProvider.overrideWithValue(registry),
        authRepositoryProvider.overrideWithValue(auth),
        firestoreAccountRepositoryProvider.overrideWith(
          (ref) async => FirestoreAccountRepository(
            firestore: firestore,
            uid: auth.currentUser?.uid ?? 'fb-uid-local',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
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
  }

  testWidgets(
    'switching to a saved local account sets activeAccountIdProvider to its '
    'accountId — before this wiring it stayed null forever',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(activeAccountIdProvider), isNull);

      await tester.tap(find.text('Local User'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(activeAccountIdProvider), 'acc-local');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  group('cloud account instant switch', () {
    const cloudUid = 'fb-uid-cloud-instant';
    const cloudEmail = 'instant@test.cloud';

    Future<void> seedInstantCloudAccount() async {
      when(() => auth.currentUser).thenReturn(_user(cloudUid, cloudEmail));
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => auth.currentUser);
      when(() => auth.reauthWithGoogleSilently()).thenAnswer((_) async => null);

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

    testWidgets(
      'instant switch (valid session) sets activeAccountIdProvider to the '
      "tapped account's accountId",
      (tester) async {
        await seedInstantCloudAccount();
        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Instant Cloud'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(container.read(activeAccountIdProvider), 'acc-cloud-instant');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // NOTE: the picker's swipe-to-remove reset (_onDismissed's active-account
  // branch, which also calls `activeAccountIdProvider.notifier.set(null)`)
  // is NOT covered here — unlike every other call site in this screen, that
  // method navigates via `ref.read(routerProvider)` (the real app router),
  // not the mocked `StackRouter` this harness injects via `StackRouterScope`
  // for the switch flows above, so it cannot be driven the same way. See
  // `account_actions_test.dart`'s "DeletingAccountOverlay success resets
  // activeAccountIdProvider to null" test for red-demo coverage of the
  // equivalent reset-on-delete call site in `account_actions.dart`, which
  // mocks `routerProvider` directly.
}
