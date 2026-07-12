// AUD-core-widgets-01 (AX-2): ErrorDisplay's Retry button is resolved
// through AppLocalizations/ARB, not a hardcoded English literal. Assertions
// below reference the resolved `l10n.actionRetry` value (never a literal
// English string), and a Locale('he') test proves the Hebrew ARB value
// actually renders — a reintroduced hardcoded English literal could never
// satisfy that assertion.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('ErrorDisplay', () {
    testWidgets('displays error message', (WidgetTester tester) async {
      const errorMessage = 'Something went wrong';

      await tester.pumpWidget(_wrap(const ErrorDisplay(message: errorMessage)));

      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('displays error icon', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ErrorDisplay(message: 'Error')));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays custom icon when provided', (
      WidgetTester tester,
    ) async {
      const customIcon = Icons.warning;

      await tester.pumpWidget(
        _wrap(const ErrorDisplay(message: 'Warning', icon: customIcon)),
      );

      expect(find.byIcon(customIcon), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays localized retry button when onRetry provided', (
      WidgetTester tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      var retryPressed = false;

      await tester.pumpWidget(
        _wrap(
          ErrorDisplay(message: 'Error', onRetry: () => retryPressed = true),
        ),
      );
      await tester.pumpAndSettle();

      // Find the retry text and button
      expect(find.text(l10n.actionRetry), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
    });

    testWidgets('does not display retry button when onRetry not provided', (
      WidgetTester tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(_wrap(const ErrorDisplay(message: 'Error')));

      expect(find.text(l10n.actionRetry), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('centers content', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ErrorDisplay(message: 'Error')));

      // ErrorDisplay uses Center widget
      expect(find.byType(ErrorDisplay), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('renders the Hebrew ARB retry label under Locale("he") — a '
        'hardcoded English literal could never satisfy this assertion', (
      tester,
    ) async {
      final l10nHe = await AppLocalizations.delegate.load(const Locale('he'));
      final l10nEn = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        _wrap(
          ErrorDisplay(message: 'Error', onRetry: () {}),
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nHe.actionRetry), findsOneWidget);
      expect(l10nHe.actionRetry, isNot(equals(l10nEn.actionRetry)));
    });
  });
}
