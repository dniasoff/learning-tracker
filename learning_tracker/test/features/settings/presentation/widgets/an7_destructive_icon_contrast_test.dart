/// AN-7 regression: destructive Sign-Out / Delete Account icons in the account
/// actions bottom sheet render as invisible solid discs when the glyph colour
/// equals the CircleAvatar container fill.
///
/// Root cause: both icons used `color: theme.colorScheme.error` inside a
/// `backgroundColor: theme.colorScheme.errorContainer` badge.  On Material 3
/// themes errorContainer is a light-red/pink (e.g. #FFCDD2) and error is a
/// deep-red (e.g. #B00020), but the perceived contrast is < 2:1 and on many
/// custom themes the pair renders as a near-invisible disc.
///
/// Fix (AN-7 wave-B): use `Colors.white` for the glyph so it always contrasts
/// against the errorContainer fill.
///
/// Test strategy: render the sheet in a lightweight ProviderScope harness,
/// verify that the logout / delete icons' `color` property is white (not the
/// `colorScheme.error` red), confirming the glyph is visible.
@Tags(['settings', 'an7', 'a11y'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider, profileListStreamProvider;
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/account_actions_sheet.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ─── Fakes / mocks ────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

class _FakePinGuard extends Fake implements PinGuard {
  @override
  void lock() {}
}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 0; // sentinel — no matching profile → treated as non-child
}

// ─── Helper ───────────────────────────────────────────────────────────────────

AppUser _cloudUser() => const AppUser(
  uid: 'uid-an7',
  email: 'an7@example.com',
  displayName: 'AN7 User',
  emailVerified: true,
  providers: [],
);

class _SheetHost extends ConsumerWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => showAccountActionsSheet(context, ref),
        child: const Text('open-sheet'),
      ),
    );
  }
}

Widget _buildApp({
  required _MockAppRouter router,
  required _MockAuthRepository authRepo,
  required _MockAccountManagementService service,
  required DeviceRegistryDatabase registry,
}) {
  return ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountManagementServiceProvider.overrideWithValue(service),
      userDatabaseProvider.overrideWithValue(
        UserDatabase(NativeDatabase.memory()),
      ),
      deviceRegistryProvider.overrideWithValue(registry),
      currentAccountIdProvider.overrideWith((ref) => 1),
      authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
      activeProfileIdProvider.overrideWith(() => _ActiveProfileIdOverride()),
      profileListStreamProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _SheetHost(),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockAppRouter router;
  late _MockAuthRepository authRepo;
  late _MockAccountManagementService service;
  late DeviceRegistryDatabase registry;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(<PageRouteInfo>[]);
  });

  setUp(() {
    router = _MockAppRouter();
    authRepo = _MockAuthRepository();
    service = _MockAccountManagementService();
    registry = DeviceRegistryDatabase(NativeDatabase.memory());

    when(
      () => router.replaceAll(any<List<PageRouteInfo>>()),
    ).thenAnswer((_) async {});
    when(() => router.push(any<PageRouteInfo>())).thenAnswer((_) async => null);
    when(() => authRepo.signOut()).thenAnswer((_) async {});
    when(() => authRepo.currentUser).thenReturn(_cloudUser());
    when(
      () => authRepo.onAuthStateChanged(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => service.signOut()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await registry.close();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('open-sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── AN-7: glyph colour is white, NOT colorScheme.error ─────────────────────

  testWidgets(
    'AN-7: Sign Out icon colour is Colors.white (not colorScheme.error)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          authRepo: authRepo,
          service: service,
          registry: registry,
        ),
      );
      await openSheet(tester);

      // Locate the CircleAvatar that wraps the logout icon.  We find all Icon
      // widgets with the logout icon and assert the one inside the sheet uses
      // Colors.white, not a red theme colour.
      final logoutIcons = tester
          .widgetList<Icon>(find.byIcon(Icons.logout_rounded))
          .toList();

      expect(
        logoutIcons,
        isNotEmpty,
        reason: 'Sign Out row must contain the logout icon',
      );

      for (final icon in logoutIcons) {
        expect(
          icon.color,
          equals(Colors.white),
          reason:
              'AN-7: logout icon colour must be Colors.white inside '
              'errorContainer badge (was: ${icon.color})',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'AN-7: Delete Account icon colour is Colors.white (not colorScheme.error)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          authRepo: authRepo,
          service: service,
          registry: registry,
        ),
      );
      await openSheet(tester);

      final deleteIcons = tester
          .widgetList<Icon>(find.byIcon(Icons.delete_forever_rounded))
          .toList();

      expect(
        deleteIcons,
        isNotEmpty,
        reason: 'Delete Account row must contain the delete_forever icon',
      );

      for (final icon in deleteIcons) {
        expect(
          icon.color,
          equals(Colors.white),
          reason:
              'AN-7: delete icon colour must be Colors.white inside '
              'errorContainer badge (was: ${icon.color})',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
