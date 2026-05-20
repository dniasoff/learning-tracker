// Widget test for Fix M2: "Report this issue" button must do something real.
//
// Previously the onPressed was a no-op placeholder. It now:
//  1. Calls CrashlyticsService.recordError (user-initiated, non-fatal).
//  2. Shows a SnackBar confirming "Thanks — we've logged the issue."

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';

// ─── Fake Crashlytics that records calls ──────────────────────────────────────

class _RecordingCrashlyticsService implements CrashlyticsService {
  final List<({Object error, StackTrace? stack, bool fatal})> recorded = [];

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    recorded.add((error: error, stack: stack, fatal: fatal));
  }

  @override
  Future<void> setUserIdentifier(int? profileId) async {}
}

// ─── Concrete test exceptions ────────────────────────────────────────────────

class _TestInternalException extends InternalException {
  const _TestInternalException(super.message);
}

class _TestNetworkException extends NetworkException {
  const _TestNetworkException(super.message);
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

Widget _buildWidget({
  required Object error,
  StackTrace? stackTrace,
  VoidCallback? onRetry,
  required CrashlyticsService crashlytics,
}) {
  return ProviderScope(
    overrides: [crashlyticsServiceProvider.overrideWithValue(crashlytics)],
    child: MaterialApp(
      home: Scaffold(
        body: AppErrorView(
          error: error,
          stackTrace: stackTrace,
          onRetry: onRetry,
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('AppErrorView — Report this issue button (Fix M2)', () {
    testWidgets(
      'shows "Report this issue" button for InternalException (bug-report path)',
      (tester) async {
        final crashlytics = _RecordingCrashlyticsService();
        await tester.pumpWidget(
          _buildWidget(
            error: const _TestInternalException('test error'),
            crashlytics: crashlytics,
          ),
        );
        await tester.pump();

        expect(find.text('Report this issue'), findsOneWidget);
      },
    );

    testWidgets(
      '"Report this issue" button is not null — tapping it does not throw',
      (tester) async {
        final crashlytics = _RecordingCrashlyticsService();
        await tester.pumpWidget(
          _buildWidget(
            error: const _TestInternalException('test error'),
            crashlytics: crashlytics,
          ),
        );
        await tester.pump();

        // The button must be present and tappable (not a no-op null).
        final button = tester.widget<TextButton>(
          find.ancestor(
            of: find.text('Report this issue'),
            matching: find.byType(TextButton),
          ),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping "Report this issue" calls CrashlyticsService.recordError',
      (tester) async {
        final crashlytics = _RecordingCrashlyticsService();
        const err = _TestInternalException('boom');
        await tester.pumpWidget(
          _buildWidget(error: err, crashlytics: crashlytics),
        );
        await tester.pump();

        await tester.tap(find.text('Report this issue'));
        await tester.pump();

        expect(crashlytics.recorded, hasLength(1));
        expect(crashlytics.recorded.first.error, equals(err));
        expect(crashlytics.recorded.first.fatal, isFalse);
      },
    );

    testWidgets('tapping "Report this issue" shows a confirmation SnackBar', (
      tester,
    ) async {
      final crashlytics = _RecordingCrashlyticsService();
      await tester.pumpWidget(
        _buildWidget(
          error: const _TestInternalException('boom'),
          crashlytics: crashlytics,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Report this issue'));
      // Pump to allow the async onPressed and SnackBar animation to settle.
      await tester.pumpAndSettle();

      expect(find.text("Thanks — we've logged the issue."), findsOneWidget);
    });

    testWidgets(
      'does NOT show "Report this issue" for NetworkException (retry path)',
      (tester) async {
        final crashlytics = _RecordingCrashlyticsService();
        await tester.pumpWidget(
          _buildWidget(
            error: const _TestNetworkException('offline'),
            crashlytics: crashlytics,
            onRetry: () {},
          ),
        );
        await tester.pump();

        // NetworkException shows Retry, not Report.
        expect(find.text('Report this issue'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}
