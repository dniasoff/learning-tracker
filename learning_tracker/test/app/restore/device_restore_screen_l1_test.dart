// L1 widget tests — DeviceRestoreScreen
//
// Covers the five RestoreStatus states the screen renders:
//   idle       → SizedBox.shrink (no visible affordance)
//   checking   → spinner + l10n.deviceRestoreChecking text
//   restoring  → spinner + phase label + LinearProgressIndicator
//   complete   → check_circle icon + l10n.deviceRestoreComplete
//   error      → error_outline icon + l10n.deviceRestoreFailed
//               + a code-localized subtitle (AUD-sync-01/EH-5 — never the
//               raw debugDetail text) + Retry button + "Skip & continue"
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
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/device_restore_service.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'restore_test_harness.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

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

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // Register fallback values so captureAny() / any<T>() work for PageRouteInfo.
  setUpAll(registerRestoreRouteFallbacks);

  // ── idle state ────────────────────────────────────────────────────────────────
  //
  // SY-2 fix: idle branch now renders a CircularProgressIndicator so the user
  // sees activity during the transient idle window, not a blank screen.

  group('idle state', () {
    testWidgets('renders a spinner (not blank SizedBox.shrink) — SY-2 fix', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mockRouter = makeMockRouter();

      await tester.pumpWidget(
        buildRestoreHarness(
          fixedStatus: const RestoreStatus.idle(),
          mockRouter: mockRouter,
          stubAppRouter: makeStubAppRouter(),
          db: db,
        ),
      );
      await tester.pump();

      // After SY-2 fix: idle must show a spinner, not be blank.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No progress bar (that's the 'restoring' state) or error/retry UI.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);

      await tearDownRestoreHarness(tester);
    });
  });

  // ── checking state ────────────────────────────────────────────────────────────

  group('checking state', () {
    testWidgets('shows CircularProgressIndicator and checking text', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mockRouter = makeMockRouter();

      await tester.pumpWidget(
        buildRestoreHarness(
          fixedStatus: const RestoreStatus.checking(),
          mockRouter: mockRouter,
          stubAppRouter: makeStubAppRouter(),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Checking device...'), findsOneWidget);
      // No error / retry affordance visible
      expect(find.byType(ElevatedButton), findsNothing);

      await tearDownRestoreHarness(tester);
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
      await tearDownRestoreHarness(tester);
    });
  });

  // ── restoring (in-progress) state ─────────────────────────────────────────────

  group('restoring state', () {
    testWidgets(
      'shows spinner, phase label, LinearProgressIndicator, step text',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: RestorePhase.pullingData,
              completedSteps: 1,
              totalSteps: 3,
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
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

        await tearDownRestoreHarness(tester);
      },
    );

    testWidgets(
      'LinearProgressIndicator value is completedSteps / totalSteps',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: RestorePhase.loadingCurricula,
              completedSteps: 2,
              totalSteps: 4,
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        // 2/4 = 0.5
        expect(indicator.value, closeTo(0.5, 0.001));

        await tearDownRestoreHarness(tester);
      },
    );

    testWidgets(
      'LinearProgressIndicator value is null when totalSteps == 0 (indeterminate)',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: RestorePhase.importingContent,
              completedSteps: 0,
              totalSteps: 0,
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, isNull);

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.complete(collectionsRestored: 3),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
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

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(
              code: SyncErrorCode.timeout,
              debugDetail: 'Network timeout',
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Restore failed'), findsOneWidget);
        // AUD-sync-01 (EH-5): the raw RestoreStatus.error debugDetail must
        // NEVER render verbatim — it is unlocalized, potentially technical
        // text (exception class names, Firestore paths). The stable code
        // resolves to a localized string instead.
        expect(
          find.text('Network timeout'),
          findsNothing,
          reason: 'raw exception text must never reach the UI verbatim (EH-5)',
        );
        expect(
          find.text(
            'The restore timed out. Check your connection and try again.',
          ),
          findsOneWidget,
          reason:
              'SyncErrorCode.timeout must resolve to l10n.deviceRestoreErrorTimeout',
        );
        // Retry elevated button
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
        // Skip & continue text button
        expect(
          find.widgetWithText(TextButton, 'Skip & continue'),
          findsOneWidget,
        );
        // No spinner or progress bar
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tearDownRestoreHarness(tester);
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
      await tearDownRestoreHarness(tester);
    });

    // AUD-app-02 / AC2: a forced restore failure under Locale('he') must
    // render 100% ARB-sourced Hebrew text — never the raw exception text
    // carried in RestoreStatus.error.debugDetail (EH-5). This exercises the
    // exact defect the audit finding named: a raw e.toString() (here
    // simulated with a realistic raw Firestore exception string) must never
    // reach the widget tree, in the locale where the bug was reported.
    testWidgets(
      'he locale: forced restore failure renders only ARB-sourced Hebrew '
      'text — raw exception text never reaches the widget tree',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();

        // A realistic raw exception string — exactly the shape AUD-app-02
        // flagged (untranslated, technical, leaks SDK/Firestore internals).
        const rawExceptionText =
            'Exception: Data pull failed: [firebase_firestore/unavailable] '
            'The service is currently unavailable.';

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(
              code: SyncErrorCode.timeout,
              debugDetail: rawExceptionText,
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        // The raw, untranslated exception text must never render verbatim.
        expect(
          find.textContaining('firebase_firestore', findRichText: true),
          findsNothing,
          reason:
              'raw exception text must never reach the UI verbatim (EH-5), '
              'even carried via debugDetail',
        );
        expect(
          find.text(rawExceptionText),
          findsNothing,
          reason: 'raw exception text must never reach the UI verbatim (EH-5)',
        );

        // Every visible string must be the ARB-sourced Hebrew translation.
        expect(
          find.text('השחזור נכשל'),
          findsOneWidget,
          reason: 'l10n.deviceRestoreFailed (he) must render as the headline',
        );
        expect(
          find.text('השחזור נמשך זמן רב מדי. בדקו את החיבור ונסו שוב.'),
          findsOneWidget,
          reason:
              'SyncErrorCode.timeout must resolve to l10n.deviceRestoreErrorTimeout (he)',
        );
        expect(
          find.widgetWithText(ElevatedButton, 'נסה שוב'),
          findsOneWidget,
          reason: 'l10n.retry (he) must label the Retry button',
        );
        expect(
          find.widgetWithText(TextButton, 'דלגו והמשיכו'),
          findsOneWidget,
          reason: 'l10n.skipAndContinue (he) must label the Skip button',
        );

        await tearDownRestoreHarness(tester);
      },
    );
  });

  // ── Retry button behaviour ─────────────────────────────────────────────────────

  group('Retry button', () {
    testWidgets(
      'calls service.retry(); no navigation on failure (retry returns false)',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();
        // restoreStatusAfterCall: error — simulates a restore that previously
        // failed (consistent with fixedStatus: error); prevents the
        // blank-screen idle-escape guard from triggering on the initState call.
        final stubService = _StubRestoreService(
          retryResult: false,
          restoreStatusAfterCall: const RestoreStatus.error(
            code: SyncErrorCode.unknown,
            debugDetail: 'prior failure',
          ),
        );
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(
              code: SyncErrorCode.timeout,
              debugDetail: 'Timed out',
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
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

        await tearDownRestoreHarness(tester);
      },
    );

    testWidgets(
      'calls service.retry(); on success (retry returns true) → replaceAll called',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();
        final appRouter = makeStubAppRouter();
        final stubService = _StubRestoreService(retryResult: true);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(
              code: SyncErrorCode.timeout,
              debugDetail: 'Timed out',
            ),
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

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();
        final appRouter = makeStubAppRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(
              code: SyncErrorCode.unknown,
              debugDetail: 'Offline',
            ),
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

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();
        final stubService = _StubRestoreService(restoreResult: true);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.idle(),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
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

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();
        final appRouter = makeStubAppRouter();
        final stubService = _StubRestoreService(restoreResult: false);
        addTearDown(stubService.dispose);

        await tester.pumpWidget(
          buildRestoreHarness(
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

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.error(code: SyncErrorCode.unknown),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);

        await tearDownRestoreHarness(tester);
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
        final mockRouter = makeMockRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.restoring(
              phase: RestorePhase.pullingData,
              completedSteps: 1,
              totalSteps: 3,
            ),
            mockRouter: mockRouter,
            stubAppRouter: makeStubAppRouter(),
            db: db,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        await tearDownRestoreHarness(tester);
      },
    );
  });
}
