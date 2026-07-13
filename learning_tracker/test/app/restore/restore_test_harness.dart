// Shared mock/stub harness for DeviceRestoreScreen widget tests.
//
// Extracted from 4 near-byte-identical copies of `_MockStackRouter` /
// `_MockRestoreGuard` / `_StubAppRouter` / `_buildHarness()` that had
// accreted across device_restore_phase_l10n_test.dart,
// device_restore_screen_l1_test.dart, device_restore_screen_overflow_test.dart
// and sy2_device_restore_idle_blank_test.dart (AUD-t-cross-23, TQ-3).
//
// Dart privacy is per-library (per-file): a leading-underscore identifier is
// invisible outside the file that declares it, even to files that `import`
// it. So the mock classes below stay private to THIS file — they were never
// usable across files anyway — and are exposed to the 4 consuming test files
// only through the public factory functions beneath them. Callers get back
// values typed by the real public interfaces (`StackRouter`, `AppRouter`),
// never the mock classes themselves.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/device_restore_screen.dart';
import 'package:learning_tracker/app/restore/device_restore_service.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks (private — reach these only through the factories below) ────────

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

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ── Public factories ───────────────────────────────────────────────────────

/// A stubbed [StackRouter] with `replaceAll`/`push` wired to succeed.
StackRouter makeMockRouter() {
  final r = _MockStackRouter();
  when(() => r.replaceAll(any())).thenAnswer((_) async => []);
  when(() => r.push(any())).thenAnswer((_) async => null);
  return r;
}

/// An [AppRouter] stand-in exposing a mock [RestoreGuard] so the screen can
/// call `router.restoreGuard.markRestoreComplete()` without real guard logic.
AppRouter makeStubAppRouter() =>
    _StubAppRouter(restoreGuard: _MockRestoreGuard());

/// Registers the fallback route values mocktail's `any()`/`captureAny()`
/// need for [PageRouteInfo]-typed arguments. Call once from `setUpAll`.
void registerRestoreRouteFallbacks() {
  registerFallbackValue(const AppShellRoute());
  registerFallbackValue(<PageRouteInfo>[const AppShellRoute()]);
  registerFallbackValue(const ProfilePickerRoute());
}

/// Builds the standard DeviceRestoreScreen pump rig: a [ProviderScope] with
/// the restore/router/database/profile overrides the screen reads directly,
/// wrapped in a [MaterialApp] carrying the real l10n delegates, with the
/// screen mounted under a [StackRouterScope] driven by [mockRouter].
///
/// [fixedStatus] overrides [restoreStatusProvider] so the screen renders
/// that state immediately. [service] overrides [deviceRestoreServiceProvider]
/// — pass null (the default) for rendering-only tests, so `initState`'s
/// `_startRestore` early-returns instead of doing real I/O.
Widget buildRestoreHarness({
  required RestoreStatus fixedStatus,
  required StackRouter mockRouter,
  required AppRouter stubAppRouter,
  required UserDatabase db,
  DeviceRestoreService? service,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      restoreStatusProvider.overrideWithValue(fixedStatus),
      deviceRestoreServiceProvider.overrideWithValue(service),
      routerProvider.overrideWithValue(stubAppRouter),
      userDatabaseProvider.overrideWithValue(db),
      currentAccountIdProvider.overrideWithValue(1),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(null),
      ),
    ],
    child: MaterialApp(
      locale: locale,
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
        child: const DeviceRestoreScreen(),
      ),
    ),
  );
}

/// Standard teardown: unmount the screen and flush one empty frame so
/// in-flight timers/streams from the previous case don't leak into the next.
Future<void> tearDownRestoreHarness(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
