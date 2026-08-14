// Multi-device overflow guard for the SETTINGS feature's dialogs / sheet.
//
// Each surface below could previously throw "RenderFlex overflowed by N pixels"
// on a small screen / large accessibility text:
//
//   * ReauthenticateDialog       — Column + TextField, now via showAppDialog.
//   * ChangePasswordDialog       — Form Column + 2 fields, now via showAppDialog.
//   * AccountActionsSheet        — up to 5 ListTiles, now in a SingleChildScrollView.
//   * Sign-out confirmation      — icon + body + 2 buttons, now scroll-wrapped.
//
// We render each surface's REAL widget (auto-opening the dialog/sheet via a
// post-frame callback) and assert no overflow across the device/text-scale
// matrix using [expectNoOverflowAcrossDevices]. Flutter overflow is monotonic,
// so passing the extreme corners proves the whole continuum of real devices.

@Tags(['overflow', 'settings'])
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
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/account_actions_sheet.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/overflow_harness.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

class _FakePinGuard extends Fake implements PinGuard {
  @override
  void lock() {}
}

class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => '01ARZ3NDEKTSV4RRFFQ69G5FAV';
}

AppUser _cloudUser() => const AppUser(
  uid: 'uid-test',
  email: 'a-fairly-long-email-address@example-domain.com',
  displayName: 'Test User',
  emailVerified: true,
  // password provider → "Change password" row also renders (5 rows total).
  providers: ['password'],
);

// ─── Auto-opening hosts (open the real dialog/sheet once mounted) ───────────────

/// Opens [showReauthenticateDialog] as soon as it's mounted.
class _ReauthHost extends StatefulWidget {
  const _ReauthHost({required this.service});
  final AccountManagementService service;

  @override
  State<_ReauthHost> createState() => _ReauthHostState();
}

class _ReauthHostState extends State<_ReauthHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showReauthenticateDialog(
        context: context,
        email: 'a-fairly-long-email-address@example-domain.com',
        service: widget.service,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Opens [showChangePasswordDialog] as soon as it's mounted.
class _ChangePasswordHost extends StatefulWidget {
  const _ChangePasswordHost({required this.service});
  final AccountManagementService service;

  @override
  State<_ChangePasswordHost> createState() => _ChangePasswordHostState();
}

class _ChangePasswordHostState extends State<_ChangePasswordHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showChangePasswordDialog(context: context, service: widget.service);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Opens the [showSignOutConfirmation] dialog as soon as it's mounted. Uses a
/// ConsumerStatefulWidget so it can pass the real `ref` the flow expects.
class _SignOutHost extends ConsumerStatefulWidget {
  const _SignOutHost();

  @override
  ConsumerState<_SignOutHost> createState() => _SignOutHostState();
}

class _SignOutHostState extends ConsumerState<_SignOutHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fire-and-forget: we only care that the confirmation dialog lays out
      // without overflow. The post-confirm sign-out path is not exercised here.
      showSignOutConfirmation(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Opens the real account-actions bottom sheet as soon as it's mounted.
class _AccountActionsSheetHost extends ConsumerStatefulWidget {
  const _AccountActionsSheetHost();

  @override
  ConsumerState<_AccountActionsSheetHost> createState() =>
      _AccountActionsSheetHostState();
}

class _AccountActionsSheetHostState
    extends ConsumerState<_AccountActionsSheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAccountActionsSheet(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

// ─── Provider overrides for the sheet / sign-out flows ──────────────────────────

List<Override> _sheetOverrides({
  required DeviceRegistryDatabase registry,
  required AuthRepository authRepo,
  required AccountManagementService service,
  required AppRouter router,
}) {
  return [
    routerProvider.overrideWithValue(router),
    authRepositoryProvider.overrideWithValue(authRepo),
    accountManagementServiceProvider.overrideWithValue(service),
    deviceRegistryProvider.overrideWithValue(registry),
    authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
    activeProfileIdProvider.overrideWith(() => _ActiveProfileIdOverride()),
    profileListStreamProvider.overrideWith((ref) => Stream.value(const [])),
  ];
}

void main() {
  setUpAll(() {
    registerFallbackValue(<PageRouteInfo>[]);
  });

  // ── P1 dialogs (showAppDialog-backed) ──────────────────────────────────────

  testWidgets(
    'ReauthenticateDialog does not overflow across the device matrix',
    (tester) async {
      final service = _MockAccountManagementService();
      await expectNoOverflowAcrossDevices(
        tester,
        () => _ReauthHost(service: service),
      );
    },
  );

  testWidgets(
    'ChangePasswordDialog does not overflow across the device matrix',
    (tester) async {
      final service = _MockAccountManagementService();
      await expectNoOverflowAcrossDevices(
        tester,
        () => _ChangePasswordHost(service: service),
      );
    },
  );

  // ── P3 sign-out confirmation dialog (scroll-wrapped) ────────────────────────

  testWidgets(
    'Sign-out confirmation dialog does not overflow across the device matrix',
    (tester) async {
      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(registry.close);
      final authRepo = _MockAuthRepository();
      final service = _MockAccountManagementService();
      final router = _MockAppRouter();
      when(() => authRepo.currentUser).thenReturn(_cloudUser());
      when(
        () => authRepo.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream.empty());

      await expectNoOverflowAcrossDevices(
        tester,
        () => const _SignOutHost(),
        overrides: _sheetOverrides(
          registry: registry,
          authRepo: authRepo,
          service: service,
          router: router,
        ),
      );
    },
  );

  // ── P2 account-actions bottom sheet (SingleChildScrollView) ─────────────────

  testWidgets(
    'AccountActionsSheet (5 rows) does not overflow across the device matrix',
    (tester) async {
      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(registry.close);
      final authRepo = _MockAuthRepository();
      final service = _MockAccountManagementService();
      final router = _MockAppRouter();
      // password + cloud-born user → all five rows render (switch / add /
      // change password / sign out / delete) — the worst-case row count.
      when(() => authRepo.currentUser).thenReturn(_cloudUser());
      when(
        () => authRepo.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream.empty());

      await expectNoOverflowAcrossDevices(
        tester,
        () => const _AccountActionsSheetHost(),
        overrides: _sheetOverrides(
          registry: registry,
          authRepo: authRepo,
          service: service,
          router: router,
        ),
      );
    },
  );
}
