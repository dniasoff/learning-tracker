import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/account_creation_screen.dart';
import '../../../../mocks/mock_repositories.dart';

void main() {
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
      child: const MaterialApp(home: AccountCreationScreen()),
    );
  }

  group('AccountCreationScreen Widget Tests', () {
    testWidgets('displays email and password fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
    });

    testWidgets('displays Create Account button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.widgetWithText(FilledButton, 'Create Account'),
        findsOneWidget,
      );
    });

    testWidgets('displays Google Sign-In button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Sign up with Google'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap create account without filling fields
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Display name is required'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows validation error for short password', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '12345',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('OR divider is shown between email and Google options', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('OR'), findsOneWidget);
    });
  });
}
