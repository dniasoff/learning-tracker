import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/auth/presentation/screens/sign_in_screen.dart';

void main() {
  group('SignInScreen', () {
    Widget buildTestWidget() {
      return const ProviderScope(child: MaterialApp(home: SignInScreen()));
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows Sign In button and Google sign-in option', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets); // AppBar title + button
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
    });

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });
}
