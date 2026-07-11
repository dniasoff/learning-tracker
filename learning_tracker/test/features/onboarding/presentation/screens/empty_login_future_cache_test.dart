// Regression test for AUD-onboarding-09: EmptyLoginScreen must not
// reconstruct the registry.getAllAccounts() Future on every rebuild.
// See: docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-onboarding-09.json
//
// BUG LOG:
//   - RED (pre-fix): EmptyLoginScreen was a ConsumerWidget calling
//     `FutureBuilder(future: ref.read(deviceRegistryProvider).getAllAccounts())`
//     directly inside `build()`. Any unrelated rebuild of EmptyLoginScreen
//     (theme change, locale change, any ancestor rebuild) constructed a
//     brand new Future, restarting the FutureBuilder into
//     ConnectionState.waiting and re-invoking getAllAccounts() a second
//     time — flickering the account-switch icon on unrelated rebuilds.
//   - Mirrors the identical fix already shipped for AccountPickerScreen
//     under AUD-account-07 (see account_picker_future_cache_test.dart).

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/empty_login_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockStackRouter extends Mock implements StackRouter {}

// Stub gateway so DeviceNotificationToggle doesn't crash in tests.
class _StubNotificationGateway extends Mock implements NotificationGateway {
  @override
  Future<bool> hasPermission() async => false;
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

/// An unrelated riverpod provider — standing in for any provider elsewhere
/// in the app that EmptyLoginScreen's ancestors might depend on. Bumping it
/// forces an ancestor rebuild that reaches EmptyLoginScreen WITHOUT
/// EmptyLoginScreen's own inputs changing, and without remounting it.
class _UnrelatedRebuildTrigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _unrelatedRebuildTriggerProvider =
    NotifierProvider<_UnrelatedRebuildTrigger, int>(
      _UnrelatedRebuildTrigger.new,
    );

/// Hosts EmptyLoginScreen as a non-const child of a widget that watches the
/// unrelated trigger provider above. Because the child is constructed fresh
/// (non-const) on every host rebuild but keeps the same runtimeType and no
/// key, Flutter reconciles it via Element.update() — i.e. an ordinary
/// "ancestor rebuild" that preserves EmptyLoginScreen's State rather than
/// remounting it. This is exactly the class of rebuild the finding warns
/// about (theme change / locale change / any ancestor rebuild).
class _RebuildHost extends ConsumerWidget {
  const _RebuildHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_unrelatedRebuildTriggerProvider);
    // Must NOT be const: a const child would be canonicalized/identical
    // across rebuilds and the framework would skip re-invoking build()
    // entirely, defeating the point of this test.
    // ignore: prefer_const_constructors
    return EmptyLoginScreen();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  testWidgets(
    'an unrelated ancestor rebuild does not re-invoke getAllAccounts()',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        kOnboardingSkipped: true,
        kOnboardingJoinedToTutor: false,
      });
      final registry = _CountingRegistry();
      addTearDown(registry.close);

      final mockRouter = _MockStackRouter();
      when(
        () => mockRouter.push(any<PageRouteInfo>()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceRegistryProvider.overrideWithValue(registry),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  profileId: 1,
                  email: 'test@test.com',
                  displayName: 'Test',
                ),
                tier: Tier.localBorn,
              ),
            ),
            notificationServiceProvider.overrideWithValue(
              _StubNotificationGateway(),
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
              controller: mockRouter,
              stateHash: 0,
              child: const _RebuildHost(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Initial build has resolved — exactly one query so far.
      expect(registry.getAllAccountsCallCount, 1);

      // Trigger an UNRELATED ancestor rebuild: bump a provider EmptyLoginScreen
      // itself neither watches nor reads. _RebuildHost rebuilds and hands
      // EmptyLoginScreen a brand-new (non-identical) widget instance in the
      // same slot — Flutter updates the existing element rather than
      // remounting it.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_RebuildHost)),
      );
      container.read(_unrelatedRebuildTriggerProvider.notifier).bump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // getAllAccounts() must not have been invoked a second time.
      expect(
        registry.getAllAccountsCallCount,
        1,
        reason:
            'an unrelated ancestor rebuild must not reconstruct the '
            'getAllAccounts() Future',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
