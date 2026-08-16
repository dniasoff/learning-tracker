// L1 widget tests for account_actions.dart
//
// Covers:
//
// showSignOutConfirmation
//   • dialog renders Sign Out title
//   • dialog renders "Are you sure" body text
//   • dialog shows Sign Out confirm button (FilledButton)
//   • dialog shows Cancel button
//   • pressing Cancel dismisses dialog WITHOUT calling service.signOut
//   • pressing Sign Out (confirm) calls service.signOut + authRepo.signOut
//   • pressing Sign Out with accounts remaining → router.replaceAll([AccountPickerRoute])
//   • pressing Sign Out with no accounts → router.replaceAll([SignInRoute])
//   • sign-out exception → SnackBar with errorSignOutFailed text
//   • Hebrew locale: dialog renders without overflow/crash
//
// showDeleteAccountFlow
//   • null user → flow exits immediately (no dialog)
//   • offline check: isOnline = false → SnackBar with errorDeleteAccountRequiresInternet
//   • online + null providers → showDeleteAccountDialog shown (type DELETE prompt)
//   • Delete Account button disabled until 'DELETE' is typed
//   • Cancel on delete dialog → no deletion
//   • password user: after DELETE-confirm → reauthenticate dialog shown
//   • password reauth: Cancel exits without calling deleteAccount
//   • google user: after DELETE-confirm → Google reauth explanation dialog shown
//   • google reauth cancel → exits without deletion
//   • no providers (non-password/non-google) → DeletingAccountOverlay shown
//
// _DeletingAccountOverlay (via showDeleteAccountFlow wiring)
//   • progress state: spinner + deletingAccountTitle shown
//   • success: deleteAccount called, router.replaceAll([SignInRoute])
//   • error state: error icon + retry button + cancel button rendered
//   • retry button: re-calls deleteAccount
//   • cancel button on error: router.replaceAll([SignInRoute]) called
//
// PROTOCOL: pump() + pump(Duration(seconds:1)); no pumpAndSettle.
// Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero) per test.

@Tags(['l1', 'settings', 'account_actions'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show NotAuthenticatedException;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
// ignore_for_file: directives_ordering
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

class _MockConnectivityGateway extends Mock implements ConnectivityGateway {}

class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

class _FakePinGuard extends Fake implements PinGuard {
  @override
  void lock() {}
}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Stub AuthStateNotifier that starts signedOut and accepts signOut calls
/// without reading any providers.
class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

AppUser _cloudUser({
  String uid = 'uid-test',
  List<String> providers = const [],
  String email = 'user@example.com',
}) => AppUser(
  uid: uid,
  email: email,
  displayName: 'Test User',
  emailVerified: true,
  providers: providers,
);

/// Seeds one account into [registry] and returns it.
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

/// Host widget that triggers showSignOutConfirmation.
class _SignOutHost extends ConsumerWidget {
  const _SignOutHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => showSignOutConfirmation(context, ref),
        child: const Text('trigger'),
      ),
    );
  }
}

/// Host widget that triggers showDeleteAccountFlow.
class _DeleteHost extends ConsumerWidget {
  const _DeleteHost({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => showDeleteAccountFlow(context, ref, user),
        child: const Text('trigger'),
      ),
    );
  }
}

Widget _buildApp({
  required Widget child,
  required _MockAppRouter router,
  required _MockAuthRepository authRepo,
  required _MockAccountManagementService service,
  required _MockConnectivityGateway connectivity,
  required DeviceRegistryDatabase registry,
  List<Override> extra = const [],
  Locale locale = const Locale('en'),
}) {
  return pumpApp(
    locale: locale,
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountManagementServiceProvider.overrideWithValue(service),
      connectivityServiceProvider.overrideWithValue(connectivity),
      deviceRegistryProvider.overrideWithValue(registry),
      authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
      ...extra,
    ],
    child: child,
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockAppRouter router;
  late _MockAuthRepository authRepo;
  late _MockAccountManagementService service;
  late _MockConnectivityGateway connectivity;
  late DeviceRegistryDatabase registry;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(<PageRouteInfo>[]);
  });

  setUp(() {
    router = _MockAppRouter();
    authRepo = _MockAuthRepository();
    service = _MockAccountManagementService();
    connectivity = _MockConnectivityGateway();
    registry = DeviceRegistryDatabase(NativeDatabase.memory());

    when(
      () => router.replaceAll(any<List<PageRouteInfo>>()),
    ).thenAnswer((_) async {});
    when(() => authRepo.signOut()).thenAnswer((_) async {});
    when(() => authRepo.currentUser).thenReturn(null);
    when(
      () => authRepo.onAuthStateChanged(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => service.signOut()).thenAnswer((_) async {});
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await registry.close();
  });

  // ── showSignOutConfirmation — Dialog content ─────────────────────────────────

  testWidgets('sign-out dialog renders "Sign Out" title text', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

    // Title text "Sign Out" appears in the dialog
    expect(find.text('Sign Out'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('sign-out dialog body contains "Are you sure" text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(
      find.textContaining('Are you sure you want to sign out'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('sign-out dialog has a FilledButton confirm button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Sign Out'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('sign-out dialog has a Cancel button', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showSignOutConfirmation — Cancel path ────────────────────────────────────

  testWidgets(
    'pressing Cancel dismisses dialog WITHOUT calling service.signOut',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: const _SignOutHost(),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verifyNever(() => service.signOut());
      verifyNever(() => authRepo.signOut());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── showSignOutConfirmation — Confirm path ───────────────────────────────────

  testWidgets(
    'pressing Sign Out confirm calls service.signOut AND authRepo.signOut',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: const _SignOutHost(),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => service.signOut()).called(1);
      verify(() => authRepo.signOut()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'sign-out with accounts remaining navigates to AccountPickerRoute',
    (tester) async {
      await _seedAccount(registry, accountId: 'acc-1', email: 'a@b.com');

      await tester.pumpWidget(
        _buildApp(
          child: const _SignOutHost(),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

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

  testWidgets('sign-out with no accounts navigates to SignInRoute', (
    tester,
  ) async {
    // registry is empty by default
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

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
  });

  testWidgets(
    'sign-out exception shows SnackBar with errorSignOutFailed text',
    (tester) async {
      when(() => service.signOut()).thenThrow(Exception('network error'));

      await tester.pumpWidget(
        _buildApp(
          child: const _SignOutHost(),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Failed to sign out. Please try again.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Hebrew locale smoke test ─────────────────────────────────────────────────

  testWidgets('Hebrew locale: sign-out dialog renders without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _SignOutHost(),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showDeleteAccountFlow — null user ────────────────────────────────────────

  testWidgets('null user: flow exits immediately — no dialog shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const _DeleteHost(user: null),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showDeleteAccountFlow — offline ─────────────────────────────────────────

  testWidgets('offline: shows SnackBar with internet-required message', (
    tester,
  ) async {
    when(() => connectivity.isOnline).thenAnswer((_) async => false);
    final user = _cloudUser();

    await tester.pumpWidget(
      _buildApp(
        child: _DeleteHost(user: user),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // errorDeleteAccountRequiresInternet contains 'internet'
    expect(find.textContaining('internet'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showDeleteAccountFlow — DeleteAccountDialog shown ───────────────────────

  testWidgets(
    'online user: shows Delete Account confirmation dialog with type-DELETE field',
    (tester) async {
      final user = _cloudUser(providers: const []);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Delete Account'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'delete dialog: Delete Account button is disabled until DELETE is typed',
    (tester) async {
      final user = _cloudUser(providers: const []);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Button starts disabled
      final deleteBtn = find.widgetWithText(TextButton, 'Delete Account');
      expect(tester.widget<TextButton>(deleteBtn).onPressed, isNull);

      // Type 'DELETE' → button becomes enabled
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      expect(tester.widget<TextButton>(deleteBtn).onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('delete dialog: Cancel exits without calling deleteAccount', (
    tester,
  ) async {
    final user = _cloudUser(providers: const []);

    await tester.pumpWidget(
      _buildApp(
        child: _DeleteHost(user: user),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => service.deleteAccount(any<String>()));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showDeleteAccountFlow — password user path ───────────────────────────────

  testWidgets('password user: after DELETE confirm shows reauthenticate dialog', (
    tester,
  ) async {
    final user = _cloudUser(
      providers: const ['password'],
      email: 'pw@example.com',
    );

    await tester.pumpWidget(
      _buildApp(
        child: _DeleteHost(user: user),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // ReauthenticateDialog shows 'Verify Your Identity' (l10n.reauthDialogTitle)
    expect(find.text('Verify Your Identity'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('password reauth: Cancel exits without calling deleteAccount', (
    tester,
  ) async {
    final user = _cloudUser(
      providers: const ['password'],
      email: 'pw@example.com',
    );

    await tester.pumpWidget(
      _buildApp(
        child: _DeleteHost(user: user),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Cancel on the reauth dialog
    await tester.tap(find.text('Cancel').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => service.deleteAccount(any<String>()));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── showDeleteAccountFlow — Google user path ─────────────────────────────────

  testWidgets(
    'google user: after DELETE confirm shows Google reauth explanation dialog',
    (tester) async {
      final user = _cloudUser(providers: const ['google.com']);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Google reauth dialog: l10n.reauthGoogleTitle
      expect(
        find.text('Confirm with Google to delete your account'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'google reauth: Cancel exits without calling reauthenticateWithGoogle',
    (tester) async {
      final user = _cloudUser(providers: const ['google.com']);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verifyNever(() => service.reauthenticateWithGoogle());
      verifyNever(() => service.deleteAccount(any<String>()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── showDeleteAccountFlow — no-provider → DeletingAccountOverlay ─────────────

  testWidgets(
    'no-provider user: after DELETE confirm shows DeletingAccountOverlay with spinner',
    (tester) async {
      final user = _cloudUser(providers: const []);
      final deleteCompleter = Completer<void>();
      when(
        () => service.deleteAccount(any<String>()),
      ).thenAnswer((_) => deleteCompleter.future);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Overlay is showing while delete is in progress
      expect(find.text('Deleting your account…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve to clean up
      deleteCompleter.complete();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'DeletingAccountOverlay success: deleteAccount called + router.replaceAll([SignInRoute])',
    (tester) async {
      final user = _cloudUser(providers: const []);
      when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => service.deleteAccount(user.uid)).called(1);
      final captured = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      final routes = captured.last as List<PageRouteInfo>;
      expect(routes.first, isA<SignInRoute>());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── activeAccountIdProvider wiring (Epic C account activation) ─────────────
  //
  // Red-demo: before `_runDeletion` (account_actions.dart) called
  // `activeAccountIdProvider.notifier.set(null)`, this provider stayed
  // whatever it was forever — deleting the active account never cleared it.
  // Requires a device-registry row matching the deleted Firebase uid so the
  // current Firestore-era `_runDeletion` path clears activeAccountIdProvider
  // before removing that account from the device registry. The existing
  // "success" test above seeds no registry row, so it never exercises this
  // branch.
  testWidgets(
    'DeletingAccountOverlay success resets activeAccountIdProvider to null '
    'when the deleted account is the currently-active device account',
    (tester) async {
      final user = _cloudUser(
        providers: const [],
        uid: 'fb-uid-active-del',
        email: 'active-del@example.com',
      );
      when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {});

      const dbFileName = 'db_active-del';
      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-active-del',
          email: 'active-del@example.com',
          displayName: 'Active Del',
          tier: 'cloudBorn',
          firebaseUid: Value(user.uid),
          dbFileName: dbFileName,
          createdAt: DateTime.utc(2026, 1, 1),
          lastUsedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          routerProvider.overrideWithValue(router),
          authRepositoryProvider.overrideWithValue(authRepo),
          accountManagementServiceProvider.overrideWithValue(service),
          connectivityServiceProvider.overrideWithValue(connectivity),
          deviceRegistryProvider.overrideWithValue(registry),
          authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
        ],
      );
      addTearDown(container.dispose);
      // Seed the "currently active" state exactly as a prior sign-in/switch
      // would have through the live Firestore account selector.
      container.read(activeAccountIdProvider.notifier).set('acc-active-del');

      await tester.pumpWidget(
        pumpApp(
          container: container,
          child: _DeleteHost(user: user),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(container.read(activeAccountIdProvider), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'DeletingAccountOverlay error: error icon + Retry button + Cancel rendered',
    (tester) async {
      final user = _cloudUser(providers: const []);
      var callCount = 0;
      when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('deletion failed');
      });

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Resolve second call for clean teardown
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'DeletingAccountOverlay error: never renders the raw exception message/toString() '
    '(EH-5, AUD-core-auth-03) — only the localized deletingAccountError copy shows',
    (tester) async {
      final user = _cloudUser(providers: const []);
      var callCount = 0;
      // The raw message deliberately contains a distinctive, developer-facing
      // (untranslated) fragment that must never reach the widget tree — this
      // covers BOTH a plain Exception.toString() and this finding's own
      // NotAuthenticatedException.message, since the delete flow can surface
      // either depending on where the failure originates.
      when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw const NotAuthenticatedException();
        }
      });

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Error state is showing...
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // ...via the fixed, localized copy...
      expect(
        find.text('Deletion encountered an issue. You have been signed out.'),
        findsOneWidget,
      );
      // ...and NEVER the raw, untranslated exception detail.
      expect(
        find.textContaining('NotAuthenticatedException'),
        findsNothing,
        reason:
            'EH-5 (AUD-core-auth-03): the caught exception\'s raw message/'
            'toString() must never be rendered in the UI — presentation must '
            'resolve display text via AppLocalizations only.',
      );
      expect(find.textContaining('FirebaseAuth.currentUser'), findsNothing);

      // Resolve second call for clean teardown
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('DeletingAccountOverlay error under Hebrew locale: renders only '
      'ARB-sourced Hebrew text, never a mocked exception\'s message '
      '(AUD-settings-07, EH-5/ST-4)', (tester) async {
    final user = _cloudUser(providers: const []);
    var callCount = 0;
    when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const NotAuthenticatedException();
      }
    });

    await tester.pumpWidget(
      _buildApp(
        child: _DeleteHost(user: user),
        router: router,
        authRepo: authRepo,
        service: service,
        connectivity: connectivity,
        registry: registry,
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'מחיקת חשבון'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Error state is showing via the fixed, localized Hebrew copy...
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('המחיקה נתקלה בבעיה. התנתקת מהחשבון.'), findsOneWidget);
    // ...and NEVER the raw, untranslated exception detail.
    expect(
      find.textContaining('NotAuthenticatedException'),
      findsNothing,
      reason:
          'AUD-settings-07 (EH-5): the caught exception\'s raw message/'
          'toString() must never be rendered in the UI — presentation must '
          'resolve display text via AppLocalizations only, in every '
          'locale.',
    );

    // Resolve second call for clean teardown
    await tester.tap(find.text('נסה שוב'));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'DeletingAccountOverlay retry: re-calls deleteAccount after error',
    (tester) async {
      final user = _cloudUser(providers: const []);
      var callCount = 0;
      when(() => service.deleteAccount(any<String>())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('first fail');
        // second call succeeds
      });

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Error state
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // deleteAccount was called twice total
      verify(() => service.deleteAccount(user.uid)).called(2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'DeletingAccountOverlay cancel on error: calls router.replaceAll([SignInRoute])',
    (tester) async {
      final user = _cloudUser(providers: const []);
      // Use thenAnswer (async) so the throw happens in a microtask, not
      // synchronously during initState — avoids "modify provider during build".
      when(
        () => service.deleteAccount(any<String>()),
      ).thenAnswer((_) async => throw Exception('persistent failure'));

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // At least one replaceAll([SignInRoute]) call must have been made
      final captured = verify(
        () => router.replaceAll(captureAny<List<PageRouteInfo>>()),
      ).captured;
      expect(
        captured.any(
          (list) => list is List<PageRouteInfo> && list.first is SignInRoute,
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Hebrew locale: delete flow smoke test ────────────────────────────────────

  testWidgets(
    'Hebrew locale: delete flow dialog renders without overflow/crash',
    (tester) async {
      final user = _cloudUser(providers: const []);

      await tester.pumpWidget(
        _buildApp(
          child: _DeleteHost(user: user),
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
