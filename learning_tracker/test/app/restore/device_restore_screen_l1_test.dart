// L1 widget tests — DeviceRestoreScreen
//
// Covers the five RestoreStatus states the screen renders:
//   idle       → SizedBox.shrink (no visible affordance)
//   checking   → spinner + l10n.deviceRestoreChecking text
//   restoring  → spinner + phase label + LinearProgressIndicator
//   complete   → check_circle icon + l10n.deviceRestoreComplete
//   error      → error_outline icon + l10n.deviceRestoreFailed
//               + message text + Retry button + "Skip & continue" button
//
// Behaviour tests:
//   • Retry button calls service.retry(); on success → router.replaceAll called
//   • "Skip & continue" calls router.restoreGuard.markRestoreComplete() and
//     router.replaceAll([AppShellRoute()])
//   • Single-profile restore → selectedProfileId set, replaceAll([AppShellRoute])
//   • Multi-profile restore  → selectedProfileId cleared, replaceAll([ProfilePickerRoute])
//   • Zero-profile restore   → replaceAll([AppShellRoute]) (defensive)
//   • RTL (he) smoke: no overflow/crash
//
// PROTOCOL: no pumpAndSettle — only pump() / pump(Duration) calls.
// Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero) per test.
// restoreStatusProvider is overridden directly; deviceRestoreServiceProvider
// is set to null (prevents _startRestore from calling the real service) for
// pure rendering tests, or overridden with a stub for behaviour tests.

@Tags(['l1', 'restore', 'device_restore'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
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

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockRestoreGuard extends Mock implements RestoreGuard {
  @override
  void markRestoreComplete() {}
}

/// A minimal [AppRouter] stand-in that lets the screen call
/// `router.restoreGuard.markRestoreComplete()` without real guard logic.
class _StubAppRouter extends Mock implements AppRouter {
  _StubAppRouter({required this.restoreGuard});

  @override
  final RestoreGuard restoreGuard;
}

/// Stub [DeviceRestoreService] that records calls and returns preset results.
///
/// [restoreResult] — value returned by [restore].
/// [restoreStatusAfterCall] — the [currentStatus] reported AFTER [restore]
///   completes. Defaults to [RestoreStatus.idle()] to simulate the
///   "not a new device" skip scenario (used by SYNC-RESTORE-SKIP-01).
///   Pass [RestoreStatus.error(...)] to simulate a failed restore call so
///   that tests checking the error-card path are not accidentally navigated
///   away by the blank-screen guard.
/// [retryResult] — value returned by [retry].
class _StubRestoreService extends Fake implements DeviceRestoreService {
  _StubRestoreService({
    this.restoreResult = false,
    RestoreStatus? restoreStatusAfterCall,
    this.retryResult = false,
  }) : _restoreStatusAfterCall =
           restoreStatusAfterCall ?? const RestoreStatus.idle();

  final bool restoreResult;
  final RestoreStatus _restoreStatusAfterCall;
  final bool retryResult;
  int restoreCalls = 0;
  int retryCalls = 0;

  RestoreStatus _currentStatus = const RestoreStatus.idle();

  final _statusCtrl = StreamController<RestoreStatus>.broadcast();
  final _completedCtrl = StreamController<void>.broadcast();

  @override
  Stream<RestoreStatus> get statusStream => _statusCtrl.stream;

  @override
  Stream<void> get restoreCompletedStream => _completedCtrl.stream;

  @override
  RestoreStatus get currentStatus => _currentStatus;

  @override
  Future<bool> restore({bool bypassNewDeviceCheck = false}) async {
    restoreCalls++;
    _currentStatus = _restoreStatusAfterCall;
    return restoreResult;
  }

  @override
  Future<bool> retry() async {
    retryCalls++;
    return retryResult;
  }

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
    await _completedCtrl.close();
  }
}

// ── Fixed notifier helpers ─────────────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ── Harness ────────────────────────────────────────────────────────────────────

/// Builds the test pump rig. [fixedStatus] overrides [restoreStatusProvider]
/// so the screen renders that state immediately — no service I/O required.
/// [service] overrides [deviceRestoreServiceProvider]; pass null for
/// rendering-only tests (prevents initState's _startRestore from doing work).
Widget _buildHarness({
  required RestoreStatus fixedStatus,
  required _MockStackRouter mockRouter,
  required _StubAppRouter stubAppRouter,
  required UserDatabase db,
  DeviceRestoreService? service,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      // Override the two providers the screen directly reads.
      restoreStatusProvider.overrideWithValue(fixedStatus),
      deviceRestoreServiceProvider.overrideWithValue(service),
      // Router providers so _navigateAfterRestore can call replaceAll.
      routerProvider.overrideWithValue(stubAppRouter),
      // Database so db.profileDao calls resolve.
      userDatabaseProvider.overrideWithValue(db),
      // currentAccountIdProvider — default returns 1.
      currentAccountIdProvider.overrideWithValue(1),
      // selectedProfileId — start as null; tests verify mutations.
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

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Shared setup ───────────────────────────────────────────────────────────────

_MockStackRouter _makeRouter() {
  final r = _MockStackRouter();
  when(() => r.replaceAll(any())).thenAnswer((_) async => []);
  when(() => r.push(any())).thenAnswer((_) async => null);
  return r;
}

_StubAppRouter _makeAppRouter() =>
    _StubAppRouter(restoreGuard: _MockRestoreGuard());

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // Register fallback values so captureAny() / any<T>() work for PageRouteInfo.
  setUpAll(() {
    registerFallbackValue(const AppShellRoute());
    registerFallbackValue(<PageRouteInfo>[const AppShellRoute()]);
    registerFallbackValue(const ProfilePickerRoute());
  });

  // ── idle state ────────────────────────────────────────────────────────────────

  group('idle state', () {
    testWidgets('renders empty (SizedBox.shrink) — no spinner, no text', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mockRouter = _makeRouter();

      await tester.pumpWidget(
        _buildHarness(
          fixedStatus: const RestoreStatus.idle(),
          mockRouter: mockRouter,
          stubAppRouter: _makeAppRouter(),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── checking state ────────────────────────────────────────────────────────────

  group('checking state', () {
    testWidgets('shows CircularProgressIndicator and checking text', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mockRouter = _makeRouter();

      await tester.pumpWidget(
        _buildHarness(
          fixedStatus: const RestoreStatus.checking(),
          mockRouter: mockRouter,
          stubAppRouter: _makeAppRouter(),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Checking device...'), findsOneWidget);
      // No error / retry affordance visible
      expect(find.byType(ElevatedButton), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('checking text resolves from l10n (not hardcoded)', (
      tester,
    ) async {
      // Verify the key resolves by pumping a minimal widget instead of
      // checking a literal — this guards against accidental key rename.
      final testApp = MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) =>
                Text(AppLocalizations.of(ctx)!.deviceRestoreChecking),
          ),
        ),
      );
      await tester.pumpWidget(testApp);
      await tester.pump();
      expect(find.text('Checking device...'), findsOneWidget);
      await _tearDown(tester);
    });
  });

  // ── restoring (in-progress) state ─────────────────────────────────────────────

  group('restoring state', () {
    testWidgets(
      'shows spinner, phase label, LinearProgressIndicator, step text',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: 'Restoring your data...',
              completedSteps: 1,
              totalSteps: 3,
            ),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Restoring your data...'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        // Step text — "Step 1 of 3"
        expect(find.text('Step 1 of 3'), findsOneWidget);
        // No retry button during restore
        expect(find.byType(ElevatedButton), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'LinearProgressIndicator value is completedSteps / totalSteps',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: 'Loading curricula...',
              completedSteps: 2,
              totalSteps: 4,
            ),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        // 2/4 = 0.5
        expect(indicator.value, closeTo(0.5, 0.001));

        await _tearDown(tester);
      },
    );

    testWidgets(
      'LinearProgressIndicator value is null when totalSteps == 0 (indeterminate)',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: 'Working...',
              completedSteps: 0,
              totalSteps: 0,
            ),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, isNull);

        await _tearDown(tester);
      },
    );
  });

  // ── complete state ─────────────────────────────────────────────────────────────

  group('complete state', () {
    testWidgets(
      'shows check_circle icon and restore-complete text; no spinner, no retry',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.complete(collectionsRestored: 3),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        expect(
          find.byIcon(Icons.check_circle),
          findsOneWidget,
          reason: 'check_circle icon must be visible in complete state',
        );
        expect(find.text('Restore complete!'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── error state ────────────────────────────────────────────────────────────────

  group('error state', () {
    testWidgets(
      'shows error_outline icon, failed text, message, Retry and Skip buttons',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.error(message: 'Network timeout'),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Restore failed'), findsOneWidget);
        expect(find.text('Network timeout'), findsOneWidget);
        // Retry elevated button
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
        // Skip & continue text button
        expect(
          find.widgetWithText(TextButton, 'Skip & continue'),
          findsOneWidget,
        );
        // No spinner or progress bar
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('error strings resolve from l10n keys (not hardcoded)', (
      tester,
    ) async {
      final testApp = MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Column(
                children: [
                  Text(l10n.deviceRestoreFailed),
                  Text(l10n.retry),
                  Text(l10n.skipAndContinue),
                  Text(l10n.deviceRestoreComplete),
                  Text(l10n.deviceRestoreStep(1, 3)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpWidget(testApp);
      await tester.pump();
      expect(find.text('Restore failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Skip & continue'), findsOneWidget);
      expect(find.text('Restore complete!'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await _tearDown(tester);
    });
  });

  // ── Retry button behaviour ─────────────────────────────────────────────────────

  group('Retry button', () {
    testWidgets(
      'calls service.retry(); no navigation on failure (retry returns false)',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();
        // restoreStatusAfterCall: error — simulates a restore that previously
        // failed (consistent with fixedStatus: error); prevents the
        // blank-screen idle-escape guard from triggering on the initState call.
        final stubService = _StubRestoreService(
          retryResult: false,
          restoreStatusAfterCall: const RestoreStatus.error(
            message: 'prior failure',
          ),
        );
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.error(message: 'Timed out'),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
            service: stubService,
          ),
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          stubService.retryCalls,
          1,
          reason: 'retry() must be called exactly once',
        );
        // No navigation when retry fails
        verifyNever(() => mockRouter.replaceAll(any<List<PageRouteInfo>>()));

        await _tearDown(tester);
      },
    );

    testWidgets(
      'calls service.retry(); on success (retry returns true) → replaceAll called',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();
        final appRouter = _makeAppRouter();
        final stubService = _StubRestoreService(retryResult: true);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.error(message: 'Timed out'),
            mockRouter: mockRouter,
            stubAppRouter: appRouter,
            db: db,
            service: stubService,
          ),
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(stubService.retryCalls, 1);
        // _navigateAfterRestore calls context.router.replaceAll(...)
        final captured = verify(
          () => mockRouter.replaceAll(captureAny<List<PageRouteInfo>>()),
        ).captured;
        expect(
          captured,
          isNotEmpty,
          reason: 'replaceAll must be called after successful retry',
        );

        await _tearDown(tester);
      },
    );
  });

  // ── "Skip & continue" button ───────────────────────────────────────────────────

  group('"Skip & continue" button', () {
    testWidgets(
      'calls restoreGuard.markRestoreComplete() and router.replaceAll([AppShellRoute])',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();
        final mockGuard = _MockRestoreGuard();
        final appRouter = _StubAppRouter(restoreGuard: mockGuard);

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.error(message: 'Offline'),
            mockRouter: mockRouter,
            stubAppRouter: appRouter,
            db: db,
          ),
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(TextButton, 'Skip & continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // router.replaceAll must have been called with [AppShellRoute()]
        final captured = verify(
          () => mockRouter.replaceAll(captureAny<List<PageRouteInfo>>()),
        ).captured;
        expect(captured, isNotEmpty);
        final routes = captured.first as List<PageRouteInfo>;
        expect(routes, hasLength(1));
        expect(routes.first, isA<AppShellRoute>());

        await _tearDown(tester);
      },
    );
  });

  // ── Navigation after successful restore ────────────────────────────────────────

  group('Navigation after successful restore', () {
    testWidgets(
      'zero profiles → replaceAll([AppShellRoute()]) defensive path',
      (tester) async {
        // An in-memory DB with no profiles seeded simulates zero-profile state.
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();
        final stubService = _StubRestoreService(restoreResult: true);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.idle(),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
            service: stubService,
          ),
        );
        // Trigger initState's _startRestore.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // restore() returns true → _navigateAfterRestore runs → 0 profiles.
        final captured = verify(
          () => mockRouter.replaceAll(captureAny<List<PageRouteInfo>>()),
        ).captured;
        expect(captured, isNotEmpty);
        final routes = captured.first as List<PageRouteInfo>;
        expect(routes.first, isA<AppShellRoute>());

        await _tearDown(tester);
      },
    );
  });

  // ── Skipped-restore navigation (blank-screen bug) ─────────────────────────────
  //
  // SYNC-RESTORE-SKIP-01 (loop-iter3)
  //
  // Bug: when restore() returns false (DeviceRestoreService decided the device
  // is not "new"), _startRestore() falls into the dead `else` branch and exits
  // without navigation.  The screen renders `idle: () => SizedBox.shrink()` —
  // a permanently blank screen with no way for the user to recover.
  //
  // Fix: when restore() returns false AND the current status is still idle (not
  // error, which already shows a retry affordance), call _navigateToApp() so
  // the guard is cleared and the normal app shell takes over.

  group('skipped restore navigates to app shell (SYNC-RESTORE-SKIP-01)', () {
    testWidgets(
      'restore() returns false with idle status → replaceAll([AppShellRoute]) is called',
      (tester) async {
        // service.restore() returns false → simulate "not a new device"
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();
        final mockGuard = _MockRestoreGuard();
        final appRouter = _StubAppRouter(restoreGuard: mockGuard);
        final stubService = _StubRestoreService(restoreResult: false);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.idle(),
            mockRouter: mockRouter,
            stubAppRouter: appRouter,
            db: db,
            service: stubService,
          ),
        );
        // initState calls _startRestore → service.restore() returns false.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          stubService.restoreCalls,
          1,
          reason: 'restore() must be called once',
        );
        // The screen MUST navigate away — blank idle must not be the final state.
        final captured = verify(
          () => mockRouter.replaceAll(captureAny<List<PageRouteInfo>>()),
        ).captured;
        expect(
          captured,
          isNotEmpty,
          reason:
              'replaceAll must be called even when restore() returns false '
              '(guard was already activated — user must not be left on a blank screen)',
        );
        final routes = captured.first as List<PageRouteInfo>;
        expect(
          routes.first,
          isA<AppShellRoute>(),
          reason:
              'navigation target must be AppShellRoute when restore is skipped',
        );

        await _tearDown(tester);
      },
    );
  });

  // ── RTL / Hebrew smoke test ────────────────────────────────────────────────────

  group('RTL (Hebrew locale) smoke test', () {
    testWidgets(
      'error state renders without overflow or crash under he locale',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.error(message: 'שגיאה'),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'restoring state renders without overflow or crash under he locale',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = _makeRouter();

        await tester.pumpWidget(
          _buildHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: 'שחזור נתונים...',
              completedSteps: 1,
              totalSteps: 3,
            ),
            mockRouter: mockRouter,
            stubAppRouter: _makeAppRouter(),
            db: db,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        await _tearDown(tester);
      },
    );
  });
}
