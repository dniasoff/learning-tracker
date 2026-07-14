// Widget tests for app_error_view.dart.
//
// Covers two fixes:
//
//  Fix M2 ("Report this issue" button must do something real):
//   1. Calls CrashlyticsService.recordError (user-initiated, non-fatal).
//   2. Shows a SnackBar confirming the report was logged.
//
//  AUD-core-widgets-01 (AX-2/EH-5): every user-facing string in AppErrorView
//  is resolved through AppLocalizations/ARB, not hardcoded English —
//  assertions below reference the resolved `l10n.*` value (never a literal
//  English string), and a Locale('he') test proves the Hebrew ARB value
//  actually renders (a reintroduced English literal would fail this test,
//  since it can never produce Hebrew text). ValidationException.message
//  (developer-facing only) must never reach the subtitle — resolved instead
//  via the stable ValidationErrorCode.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

/// A raw, developer-facing message that must NEVER be rendered in the UI —
/// EH-5 requires AppErrorView to resolve [ValidationException.code] via
/// AppLocalizations instead of surfacing [ValidationException.message].
const _rawDevOnlyMessage = 'RAW_DEV_ONLY_VALIDATION_MESSAGE_not_for_ui';

class _TestValidationException extends ValidationException {
  const _TestValidationException() : super(_rawDevOnlyMessage);
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

Widget _buildWidget({
  required Object error,
  StackTrace? stackTrace,
  VoidCallback? onRetry,
  required CrashlyticsService crashlytics,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [crashlyticsServiceProvider.overrideWithValue(crashlytics)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
    testWidgets('shows the localized report-issue button for InternalException '
        '(bug-report path)', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final crashlytics = _RecordingCrashlyticsService();
      await tester.pumpWidget(
        _buildWidget(
          error: const _TestInternalException('test error'),
          crashlytics: crashlytics,
        ),
      );
      await tester.pump();

      expect(find.text(l10n.appErrorViewReportButton), findsOneWidget);
    });

    testWidgets('report-issue button is not null — tapping it does not throw', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
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
          of: find.text(l10n.appErrorViewReportButton),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping report-issue calls CrashlyticsService.recordError', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final crashlytics = _RecordingCrashlyticsService();
      const err = _TestInternalException('boom');
      await tester.pumpWidget(
        _buildWidget(error: err, crashlytics: crashlytics),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.appErrorViewReportButton));
      await tester.pump();

      expect(crashlytics.recorded, hasLength(1));
      expect(crashlytics.recorded.first.error, equals(err));
      expect(crashlytics.recorded.first.fatal, isFalse);
    });

    testWidgets('tapping report-issue shows a localized confirmation '
        'SnackBar', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final crashlytics = _RecordingCrashlyticsService();
      await tester.pumpWidget(
        _buildWidget(
          error: const _TestInternalException('boom'),
          crashlytics: crashlytics,
        ),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.appErrorViewReportButton));
      // Pump to allow the async onPressed and SnackBar animation to settle.
      await tester.pumpAndSettle();

      expect(find.text(l10n.appErrorViewReportedSnackbar), findsOneWidget);
    });

    testWidgets('does NOT show the report-issue button for NetworkException '
        '(retry path)', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
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
      expect(find.text(l10n.appErrorViewReportButton), findsNothing);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });
  });

  group('AppErrorView — AX-2/EH-5 localization (AUD-core-widgets-01)', () {
    testWidgets('renders the Hebrew ARB value under Locale("he") — a hardcoded '
        'English literal could never satisfy this assertion', (tester) async {
      final l10nHe = await AppLocalizations.delegate.load(const Locale('he'));
      final crashlytics = _RecordingCrashlyticsService();
      await tester.pumpWidget(
        _buildWidget(
          error: const _TestInternalException('boom'),
          crashlytics: crashlytics,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();

      expect(find.text(l10nHe.appErrorViewGenericTitle), findsOneWidget);
      expect(find.text(l10nHe.appErrorViewGenericBody), findsOneWidget);
      expect(find.text(l10nHe.appErrorViewReportButton), findsOneWidget);
      // Sanity: the Hebrew string is genuinely different from the English
      // one — this would trivially "pass" if both locales rendered the
      // same (English) text due to a reintroduced hardcoded literal.
      final l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        l10nHe.appErrorViewGenericTitle,
        isNot(equals(l10nEn.appErrorViewGenericTitle)),
      );
    });

    testWidgets(
      'ValidationException: subtitle is the resolved ARB body, never the '
      'raw ValidationException.message (EH-5)',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final crashlytics = _RecordingCrashlyticsService();
        await tester.pumpWidget(
          _buildWidget(
            error: const _TestValidationException(),
            crashlytics: crashlytics,
          ),
        );
        await tester.pump();

        // The raw developer-facing message must never leak into the UI.
        expect(find.text(_rawDevOnlyMessage), findsNothing);
        // The stable ValidationErrorCode.invalidInput resolves to this ARB
        // body instead.
        expect(find.text(l10n.appErrorViewInvalidDataTitle), findsOneWidget);
        expect(find.text(l10n.appErrorViewInvalidDataBody), findsOneWidget);
      },
    );
  });

  // AUD-t-learning-02: moved from the deleted learning_screen_test.dart,
  // where this was the one non-duplicate test in the file (the other two
  // were a strict, weaker subset of learning_screen_l1_test.dart's
  // empty-state coverage, and referenced two providers LearningScreen no
  // longer reads). This test doesn't exercise LearningScreen at all — it
  // belongs here, alongside AppErrorView's other direct widget tests.
  group('AppErrorView — generic message never leaks the raw exception string '
      '(V2-R5 C3)', () {
    testWidgets(
      'InternalException: generic ARB title shown, raw exception string '
      'never rendered',
      (tester) async {
        // V2-R5 C3 regression: AppErrorView.build must never render raw
        // exception strings.
        //
        // AUD-core-sync-27: uses SeedManagerException (a real InternalException
        // leaf genuinely thrown in production — lib/core/database/seed_manager.dart)
        // instead of the removed MergeException, which was never thrown
        // anywhere in lib/ (dead scaffolding from the W7.2 backlog item; the
        // merge-failure telemetry it was meant to carry is fired via inline
        // AppLogger/analytics calls instead — W7.5/W7.6). Any InternalException
        // leaf exercises the SAME category-generic-message behavior already
        // covered by _TestInternalException above; this test's distinct value
        // is asserting the RAW message is absent, which none of the tests
        // above do for InternalException (only the ValidationException test
        // above does, for a different exception category).
        const rawMsg = 'internal error detail that must not appear in UI';
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final crashlytics = _RecordingCrashlyticsService();
        await tester.pumpWidget(
          _buildWidget(
            error: SeedManagerException(rawMsg),
            crashlytics: crashlytics,
          ),
        );
        await tester.pump();

        expect(find.byType(AppErrorView), findsOneWidget);
        expect(find.text(l10n.appErrorViewGenericTitle), findsOneWidget);
        // Raw exception message must NOT appear anywhere in the UI.
        expect(find.text(rawMsg), findsNothing);
        expect(find.textContaining(rawMsg), findsNothing);
      },
    );
  });
}
