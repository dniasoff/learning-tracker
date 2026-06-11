// Multi-device overflow guard — DeviceRestoreScreen.
//
// The screen's body switches on [RestoreStatus]; each branch is a
// MainAxisSize.min Column (spinner / progress / icon + title + message +
// buttons) inside a Center. On a short viewport / large accessibility text the
// taller branches (restoring, error) could exceed the viewport and throw
// "RenderFlex overflowed by N pixels". The body is now wrapped in a
// SingleChildScrollView so it scrolls instead.
//
// We render the REAL screen across the device/text-scale matrix using
// [expectNoOverflowAcrossDevices], overriding [restoreStatusProvider] to pin
// each visual state.
//
// Two overrides are required for the screen to render in a bare test scope:
//   * [restoreStatusProvider] — pins the visual state (restoring/complete/
//     error) so the matching body branch renders.
//   * [deviceRestoreServiceProvider] — forced to `null`. The screen's
//     `initState` calls `_startRestore`, which `ref.read`s this provider. Its
//     real builder transitively watches the sync orchestrator → auth → the
//     Firebase auth gateway, and `FirebaseAuth.instance` throws
//     "No Firebase App '[DEFAULT]'" in a test (Firebase is never initialised).
//     That surfaces as a `ProviderException: Tried to use a provider that is in
//     error state` the moment `_startRestore` reads it. Pinning the service to
//     `null` makes `_startRestore` early-return (its documented local-only
//     path) so nothing routes and no Firebase-backed provider is ever built.
//
// The `restoring` branch shows an indeterminate [CircularProgressIndicator] and
// [LinearProgressIndicator]; both animate forever, which would hang the
// harness's `pumpAndSettle`. We render the REAL screen but wrap it in
// `TickerMode(enabled: false)` so those tickers are muted — the layout (and
// therefore any overflow) is identical, but the frame loop settles. The
// wrapper is harmless for the static complete/error branches, so all three
// cases use it uniformly.
//
// Flutter overflow is monotonic, so passing the extreme corners proves the
// whole continuum of real devices.

@Tags(['overflow', 'restore'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/restore/device_restore_screen.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/overflow_harness.dart';

// ── Mocks for the null-service navigation path ─────────────────────────────────
//
// With the SY-2 fix, _startRestore calls _navigateToApp() when
// deviceRestoreServiceProvider returns null, and _navigateToApp uses
// context.router.replaceAll(...). The overflow harness wraps in a bare
// MaterialApp with no StackRouterScope, so context.router would throw.
// We wrap the screen in a StackRouterScope (with a no-op mock router) and
// add overrides for routerProvider so _navigateToApp can call
// markRestoreComplete() without error.

class _MockStackRouter extends Mock implements StackRouter {}

class _MockRestoreGuard extends Mock implements RestoreGuard {
  @override
  void markRestoreComplete() {}
}

class _StubAppRouter extends Mock implements AppRouter {
  _StubAppRouter({required this.restoreGuard});

  @override
  final RestoreGuard restoreGuard;
}

_MockStackRouter _makeRouter() {
  final r = _MockStackRouter();
  when(() => r.replaceAll(any())).thenAnswer((_) async => []);
  when(() => r.push(any())).thenAnswer((_) async => null);
  return r;
}

List<Override> _statusOverride(RestoreStatus status) => [
  restoreStatusProvider.overrideWithValue(status),
  // Local-only: keeps the real (Firebase-backed) restore-service provider
  // chain from ever building.  SY-2 fix: _startRestore now calls
  // _navigateToApp() for the null-service path, so we also override
  // routerProvider with a stub that has a mock RestoreGuard.
  deviceRestoreServiceProvider.overrideWithValue(null),
  routerProvider.overrideWithValue(
    _StubAppRouter(restoreGuard: _MockRestoreGuard()),
  ),
];

/// The real screen with its progress-indicator tickers muted so the harness's
/// `pumpAndSettle` can settle. Layout geometry is unchanged.
///
/// Wrapped in a StackRouterScope so _navigateToApp's context.router.replaceAll
/// resolves against a no-op mock (SY-2 fix: null service now navigates).
Widget _screen() => StackRouterScope(
  controller: _makeRouter(),
  stateHash: 0,
  child: const TickerMode(enabled: false, child: DeviceRestoreScreen()),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(const AppShellRoute());
    registerFallbackValue(<PageRouteInfo>[const AppShellRoute()]);
  });

  testWidgets('restoring state does not overflow across the device matrix', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      _screen,
      overrides: _statusOverride(
        const RestoreStatus.restoring(
          phase: 'Restoring your study tracks and progress from the cloud',
          completedSteps: 3,
          totalSteps: 8,
        ),
      ),
    );
  });

  testWidgets('complete state does not overflow across the device matrix', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      _screen,
      overrides: _statusOverride(
        const RestoreStatus.complete(collectionsRestored: 5),
      ),
    );
  });

  testWidgets('error state does not overflow across the device matrix', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      _screen,
      overrides: _statusOverride(
        const RestoreStatus.error(
          message:
              'We could not reach the cloud to restore your data. Check your '
              'connection and try again, or skip and continue with a fresh '
              'local copy — your cloud data will sync once you are back online.',
        ),
      ),
    );
  });
}
