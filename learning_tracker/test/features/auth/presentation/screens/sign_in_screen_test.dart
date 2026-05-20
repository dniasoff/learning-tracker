import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('SignInScreen', () {
    Widget buildTestWidget() {
      return const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      );
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Your Email'), findsOneWidget);
      expect(find.text('Secret Key'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows Sign In button and Google sign-in option', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
