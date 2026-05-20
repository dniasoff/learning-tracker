import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockStackRouter mockRouter;

  setUp(() {
    mockRouter = MockStackRouter();
    when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});
    when(() => mockRouter.maybePop()).thenAnswer((_) async => true);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        // Override authStateProvider so it doesn't hit Firebase
        authStateProvider.overrideWithValue(
          const AuthState.signedIn(
            user: AuthUser(
              profileId: 1,
              email: 'test@test.com',
              displayName: 'Test',
              userMode: 'adult',
            ),
            tier: Tier.localBorn,
          ),
        ),
      ],
      child: MaterialApp(
        home: StackRouterScope(
          controller: mockRouter,
          stateHash: 0,
          child: const OnboardingScreen(),
        ),
      ),
    );
  }

  group('OnboardingScreen Slim Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('starts at combined new profile phase', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('New Profile'), findsNothing);
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.text('Child Mode'), findsOneWidget);
      expect(find.text('Adult Mode'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Create Profile disabled with empty name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create Profile'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('child mode shows ACTIVE on Child Mode card', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Child Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('childAwareText returns adult text in adult mode', (
      tester,
    ) async {
      final result = childAwareText(
        'Choose your curricula',
        "Choose {name}'s curricula",
        'David',
      );
      expect(result, 'Choose your curricula');
    });

    testWidgets('childAwareText returns child text in child mode', (
      tester,
    ) async {
      final result = childAwareText(
        'Choose your curricula',
        "Choose {name}'s curricula",
        'David',
        isChildMode: true,
      );
      expect(result, "Choose David's curricula");
    });
  });
}
