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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/restore/device_restore_screen.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';

import '../../helpers/overflow_harness.dart';

List<Override> _statusOverride(RestoreStatus status) => [
  restoreStatusProvider.overrideWithValue(status),
  // Local-only: short-circuits `_startRestore` and keeps the real
  // (Firebase-backed) restore-service provider chain from ever building.
  deviceRestoreServiceProvider.overrideWithValue(null),
];

/// The real screen with its progress-indicator tickers muted so the harness's
/// `pumpAndSettle` can settle. Layout geometry is unchanged.
Widget _screen() =>
    const TickerMode(enabled: false, child: DeviceRestoreScreen());

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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
