// SY-2 regression tests — DeviceRestore idle blank screen
//
// Root cause (plan §ROOT sync ¶ SY-2):
//   1. The idle branch of build() returns SizedBox.shrink() — permanently blank
//      with no spinner, text, or exit when the screen enters or stays in idle.
//   2. When deviceRestoreServiceProvider returns null (local-only account),
//      _startRestore() returns early without navigating, leaving the user on
//      the blank idle screen forever.
//
// Fix: idle branch must render a spinner + "Preparing…" fallback; the
// null-service early-return must call _navigateToApp() so the app shell
// takes over and the guard is cleared.
//
// PROTOCOL: no pumpAndSettle — only pump() / pump(Duration) calls.

@Tags(['l1', 'restore', 'sy2', 'vision-fix'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:mocktail/mocktail.dart';

import 'restore_test_harness.dart';

// This file's tests always exercise the null-service (local-only account)
// path, so buildRestoreHarness's `service` parameter is left at its default
// (null) at every call site below.

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(registerRestoreRouteFallbacks);

  // SY-2a — Idle branch must render a spinner (not SizedBox.shrink).
  //
  // The idle state is a transient window while restore() runs, or a permanent
  // state when the null-service path or an uncovered false-return leaves the
  // screen stranded.  SizedBox.shrink() is fully blank — no progress, no text —
  // which looks like an app crash.  The fix renders a CircularProgressIndicator
  // so the user sees activity.
  group('SY-2a — idle branch renders spinner not blank (SY-2)', () {
    testWidgets(
      'idle status shows CircularProgressIndicator, not a blank SizedBox',
      (tester) async {
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

        // MUST show a spinner — blank screen is the SY-2 bug.
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason:
              'idle branch must render a spinner so the user sees activity, '
              'not a permanently blank SizedBox.shrink()',
        );

        await tearDownRestoreHarness(tester);
      },
    );

    testWidgets(
      'idle status must not render a completely blank body (no SizedBox.shrink)',
      (tester) async {
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

        // The idle branch must not emit a zero-size invisible widget as the
        // entire screen content.  At minimum a spinner (or text) must exist.
        final spinnerCount = tester
            .widgetList(find.byType(CircularProgressIndicator))
            .length;
        final textCount = tester.widgetList(find.byType(Text)).length;
        expect(
          spinnerCount + textCount,
          greaterThan(0),
          reason:
              'idle branch must render visible content — spinner or text — '
              'not the empty SizedBox.shrink() that causes the SY-2 blank screen',
        );

        await tearDownRestoreHarness(tester);
      },
    );
  });

  // SY-2b — Null-service early-return must navigate to app shell.
  //
  // When deviceRestoreServiceProvider returns null (local-only account),
  // _startRestore() currently does `if (service == null) return;` — it exits
  // the async method without calling _navigateToApp(). The screen then sits
  // on the idle branch forever (blank). Fix: call _navigateToApp() so the
  // guard is cleared and the app shell takes over.
  group('SY-2b — null service navigates to AppShell (SY-2)', () {
    testWidgets(
      'null deviceRestoreService on mount → replaceAll([AppShellRoute]) called',
      (tester) async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final mockRouter = makeMockRouter();
        final appRouter = makeStubAppRouter();

        await tester.pumpWidget(
          buildRestoreHarness(
            fixedStatus: const RestoreStatus.idle(),
            mockRouter: mockRouter,
            stubAppRouter: appRouter,
            db: db,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The screen must navigate away — it must NOT silently leave the user
        // on a blank idle screen because there is no restore service.
        final captured = verify(
          () => mockRouter.replaceAll(captureAny<List<PageRouteInfo>>()),
        ).captured;
        expect(
          captured,
          isNotEmpty,
          reason:
              'null-service path must call replaceAll so the user is not left '
              'stranded on the blank idle screen (SY-2 bug)',
        );
        final routes = captured.first as List<PageRouteInfo>;
        expect(
          routes.first,
          isA<AppShellRoute>(),
          reason: 'navigation target must be AppShellRoute for local-only path',
        );

        await tearDownRestoreHarness(tester);
      },
    );
  });
}
