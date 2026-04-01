import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/account_creation_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

class MockStackRouter extends Mock implements StackRouter {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockStackRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(const OnboardingRoute());
    registerFallbackValue(const OnboardingRoute());
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockRouter = MockStackRouter();
    when(() => mockRouter.push(any())).thenAnswer((_) async => null);
    when(() => mockRouter.replace(any())).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
      child: MaterialApp(
        home: StackRouterScope(
          controller: mockRouter,
          stateHash: 0,
          child: const AccountCreationScreen(),
        ),
      ),
    );
  }

  Widget createTestWidgetWithProfileService({
    required MockFirebaseAuth mockFirebaseAuth,
    required UserDatabase database,
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
        userProfileServiceProvider.overrideWith((ref) {
          return UserProfileService(
            userProfileDao: database.userProfileDao,
            pushUserProfile:
                ({
                  required String firebaseUid,
                  required String displayName,
                  required String userMode,
                }) async {},
          );
        }),
      ],
      child: MaterialApp(
        home: StackRouterScope(
          controller: mockRouter,
          stateHash: 0,
          child: const AccountCreationScreen(),
        ),
      ),
    );
  }

  group('AccountCreationScreen Widget Tests', () {
    testWidgets('displays email and password fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Create Password'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
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

      // Scroll down to make Create Account button visible
      final button = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Display name is required'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your full name'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'invalid-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min. 8 characters'),
        '123456',
      );
      final invalidEmailButton = find.widgetWithText(
        FilledButton,
        'Create Account',
      );
      await tester.ensureVisible(invalidEmailButton);
      await tester.pumpAndSettle();
      await tester.tap(invalidEmailButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows validation error for short password', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your full name'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min. 8 characters'),
        '12345',
      );
      final shortPwButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(shortPwButton);
      await tester.pumpAndSettle();
      await tester.tap(shortPwButton);
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

      expect(find.text('OR SIGN UP WITH'), findsOneWidget);
    });

    testWidgets('email sign-up success navigates to OnboardingRoute', (
      tester,
    ) async {
      final mockCredential = MockUserCredential();
      when(
        () => mockAuthRepo.signUp(any(), any(), any()),
      ).thenAnswer((_) async => mockCredential);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your full name'),
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name@example.com'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min. 8 characters'),
        'password123',
      );
      // Scroll to make confirm password field visible
      final confirmPwField = find.widgetWithText(
        TextFormField,
        'Repeat password',
      );
      await tester.ensureVisible(confirmPwField);
      await tester.pumpAndSettle();
      await tester.enterText(confirmPwField, 'password123');

      // Agree to terms
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      final signUpButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(signUpButton);
      await tester.pumpAndSettle();
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      verify(
        () => mockRouter.push(any(that: isA<OnboardingRoute>())),
      ).called(1);
    });

    testWidgets(
      'Google sign-in success navigates to OnboardingRoute for new user',
      (tester) async {
        final mockCredential = MockUserCredential();
        final mockAuth = MockFirebaseAuth();
        final mockUser = MockUser();
        final db = UserDatabase(NativeDatabase.memory());

        addTearDown(() async => db.close());

        when(
          () => mockAuthRepo.signInWithGoogle(),
        ).thenAnswer((_) async => mockCredential);
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('test-uid');

        await tester.pumpWidget(
          createTestWidgetWithProfileService(
            mockFirebaseAuth: mockAuth,
            database: db,
          ),
        );

        final googleButton = find.text('Sign up with Google');
        await tester.ensureVisible(googleButton);
        await tester.pumpAndSettle();
        await tester.tap(googleButton);
        await tester.pumpAndSettle();

        verify(
          () => mockRouter.push(any(that: isA<OnboardingRoute>())),
        ).called(1);
      },
    );
  });
}
