import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockStackRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(const AccountCreationRoute());
    registerFallbackValue(const SignInRoute());
  });

  setUp(() {
    mockRouter = MockStackRouter();
    when(() => mockRouter.push(any())).thenAnswer((_) async => null);
    when(() => mockRouter.replace(any())).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: const WelcomeScreen(),
      ),
    );
  }

  group('WelcomeScreen Widget Tests', () {
    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Torah Learning Tracker'), findsOneWidget);
    });

    testWidgets('displays app description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(
        find.textContaining('Track your Torah learning journey'),
        findsOneWidget,
      );
    });

    testWidgets('displays Get Started button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('displays sign in link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('displays app icon', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('tapping Get Started navigates to AccountCreationRoute', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      verify(
        () => mockRouter.push(any(that: isA<AccountCreationRoute>())),
      ).called(1);
    });
  });
}
