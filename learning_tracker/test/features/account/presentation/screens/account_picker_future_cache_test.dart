// Regression test for AUD-account-07: AccountPickerScreen must not
// reconstruct the registry.getAllAccounts() Future on every rebuild.
// See: docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-account-07.json
//
// BUG LOG:
//   - RED (pre-fix): AccountPickerScreen was a ConsumerWidget calling
//     `FutureBuilder(future: registry.getAllAccounts())` directly inside
//     `build()`. An unrelated provider rebuild (activeAccountIdProvider
//     changing, e.g. from a background account switch) constructed a brand
//     new Future, restarting the FutureBuilder into ConnectionState.waiting
//     and re-invoking getAllAccounts() a second time.
@Tags(['needs_flutter', 'account', 'multi_account'])
library;

import 'package:auto_route/auto_route.dart';
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
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show SelectedProfileId, selectedProfileIdProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../mocks/mock_repositories.dart';

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockStackRouter extends Mock implements StackRouter {}

class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;
  @override
  AuthState build() => _initial;
}

class _StubSelectedProfileId extends SelectedProfileId {
  @override
  String? build() => null;
}

/// Counts every call to getAllAccounts() so the test can assert the
/// registry is queried exactly once across an unrelated rebuild.
class _CountingRegistry extends DeviceRegistryDatabase {
  _CountingRegistry() : super(NativeDatabase.memory());
  int getAllAccountsCallCount = 0;

  @override
  Future<List<DeviceAccount>> getAllAccounts() {
    getAllAccountsCallCount++;
    return super.getAllAccounts();
  }
}

final _kNow = DateTime.utc(2026, 1, 1);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  testWidgets(
    'an unrelated provider rebuild does not re-invoke getAllAccounts() or '
    'revert the list to the loading spinner',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final registry = _CountingRegistry();
      final firestore = createFakeFirestore();
      await seedAccount(
        firestore,
        uid: 'fb-uid-cache',
        email: 'cache@example.test',
        displayName: 'Cache User',
      );
      await registry
          .into(registry.deviceAccounts)
          .insert(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-cache-1',
              email: 'cache@example.test',
              displayName: 'Cache User',
              tier: 'localBorn',
              dbFileName: 'user_acc_cache1.db',
              createdAt: _kNow,
              lastUsedAt: _kNow,
            ),
          );

      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      final router = _MockStackRouter();
      when(
        () => router.push(any<PageRouteInfo>()),
      ).thenAnswer((_) async => null);
      when(
        () => router.replaceAll(any<List<PageRouteInfo>>()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            deviceRegistryProvider.overrideWithValue(registry),
            authRepositoryProvider.overrideWithValue(auth),
            firestoreAccountRepositoryProvider.overrideWith(
              (ref) async => FirestoreAccountRepository(
                firestore: firestore,
                uid: 'fb-uid-cache',
              ),
            ),
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
              controller: router,
              stateHash: 0,
              child: const AccountPickerScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // List has loaded — one query so far.
      expect(find.text('Cache User'), findsOneWidget);
      expect(registry.getAllAccountsCallCount, 1);

      // Trigger an UNRELATED provider rebuild: AccountPickerScreen watches
      // activeAccountIdProvider (the current active-account selector) —
      // changing it forces build() to re-run without touching
      // deviceRegistryProvider or the account data itself.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountPickerScreen)),
      );
      container.read(activeAccountIdProvider.notifier).set('other');
      await tester.pump();

      // Must NOT flash back to the loading spinner...
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // ...the already-loaded list is still showing...
      expect(find.text('Cache User'), findsOneWidget);
      // ...and getAllAccounts() must not have been invoked a second time.
      expect(
        registry.getAllAccountsCallCount,
        1,
        reason:
            'an unrelated rebuild must not reconstruct the '
            'getAllAccounts() Future',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await registry.close();
    },
  );
}
