// Regression tests for the Settings account-header bottom sheet navigation.
//
// Both behaviours were broken by navigating with a BuildContext/ref tied to
// the dismissing sheet (or the Settings tab's nested StackRouter, which cannot
// reach root-level routes):
//
//   1. [P1] "Sign Out" (≥2 accounts) → root router.replaceAll([AccountPickerRoute])
//   2. [P2] "Switch account" → root router.push(AccountPickerRoute)
//
// The fix routes both through the ROOT AppRouter captured from `ref`, so the
// navigation survives the sheet dismissal and the auth-state teardown.
//
// PROTOCOL: pump() + pump(Duration(seconds:1)); no pumpAndSettle.
// Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero) per test.

@Tags(['l1', 'settings', 'account_actions'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
// ignore_for_file: directives_ordering
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show profileListStreamProvider;
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/account_actions_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

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
  String? build() => '01ARZ3NDEKTSV4RRFFQ69G5FAV';
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

AppUser _cloudUser() => const AppUser(
  uid: 'uid-test',
  email: 'user@example.com',
  displayName: 'Test User',
  emailVerified: true,
  providers: [],
);

Future<void> _seedAccount(
  DeviceRegistryDatabase registry, {
  String accountId = 'acc-1',
  String email = 'a@b.com',
}) async {
  final now = DateTime.utc(2026, 1, 1);
  await registry.addAccount(
    DeviceAccountsCompanion.insert(
      accountId: accountId,
      email: email,
      displayName: 'Test',
      tier: 'cloudBorn',
      createdAt: now,
      lastUsedAt: now,
      dbFileName: 'db_$accountId',
    ),
  );
}

/// Host that opens the real account-actions sheet (so we exercise the
/// post-dismissal navigation path, not the bare action helpers).
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
  List<Override> extra = const [],
}) {
  return pumpApp(
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountManagementServiceProvider.overrideWithValue(service),
      deviceRegistryProvider.overrideWithValue(registry),
      authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
      activeProfileIdProvider.overrideWith(() => _ActiveProfileIdOverride()),
      profileListStreamProvider.overrideWith((ref) => Stream.value(const [])),
      ...extra,
    ],
    child: const _SheetHost(),
  );
}

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

  testWidgets(
    'Switch account row → root router.push([AccountPickerRoute]) after sheet closes',
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

      await tester.tap(find.text('Switch account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => router.push(captureAny<PageRouteInfo>()),
      ).captured;
      expect(captured.last, isA<AccountPickerRoute>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Sign Out (≥2 accounts) → root router.replaceAll([AccountPickerRoute]) after sheet+dialog close',
    (tester) async {
      await _seedAccount(registry, accountId: 'acc-1', email: 'a@b.com');
      await _seedAccount(registry, accountId: 'acc-2', email: 'b@b.com');

      await tester.pumpWidget(
        _buildApp(
          router: router,
          authRepo: authRepo,
          service: service,
          registry: registry,
        ),
      );
      await openSheet(tester);

      // Tap the Sign Out row in the sheet → sheet closes, confirmation dialog
      // opens on the post-frame callback.
      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Confirm in the dialog.
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => service.signOut()).called(1);
      final captured = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      final routes = captured.last as List<PageRouteInfo>;
      expect(routes.first, isA<AccountPickerRoute>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Sign Out (single account) → root router.replaceAll([AccountPickerRoute])',
    (tester) async {
      await _seedAccount(registry, accountId: 'acc-only', email: 'solo@b.com');
      // Single account: getAllAccounts returns 1 → still AccountPicker path?
      // No — sign-out keeps the account row; the picker is correct with ≥1.
      // The SignInRoute branch is the EMPTY-registry case, covered below.

      await tester.pumpWidget(
        _buildApp(
          router: router,
          authRepo: authRepo,
          service: service,
          registry: registry,
        ),
      );
      await openSheet(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      final routes = captured.last as List<PageRouteInfo>;
      expect(routes.first, isA<AccountPickerRoute>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Sign Out (empty registry) → root router.replaceAll([SignInRoute]) — no regression',
    (tester) async {
      // registry left empty
      await tester.pumpWidget(
        _buildApp(
          router: router,
          authRepo: authRepo,
          service: service,
          registry: registry,
        ),
      );
      await openSheet(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      final routes = captured.last as List<PageRouteInfo>;
      expect(routes.first, isA<SignInRoute>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
