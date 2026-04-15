import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart'
    as auth_state_mod;
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';
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
  late MockFirebaseAuth mockAuth;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(const OnboardingRoute());
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockRouter = MockStackRouter();
    mockAuth = MockFirebaseAuth();
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockRouter.push(any())).thenAnswer((_) async => null);
    when(() => mockRouter.replace(any())).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
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

  Widget createTestWidgetWithDatabase({
    required MockFirebaseAuth firebaseAuth,
    required UserDatabase database,
  }) {
    final testRegistry = DeviceRegistryDatabase(NativeDatabase.memory());
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        firebaseAuthProvider.overrideWithValue(firebaseAuth),
        appDatabaseProvider.overrideWithValue(database),
        deviceRegistryProvider.overrideWithValue(testRegistry),
        auth_state_mod.authStateProvider.overrideWithValue(
          const AuthState.signedOut(),
        ),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
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

      final button = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(invalidEmailButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(shortPwButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
      // The sign-up flow performs a one-shot connectivity check via
      // InternetConnectionChecker.instance.hasConnection — in tests this
      // returns false, so the local-born offline path is taken. Provide
      // a test database so LocalAuthService can create a profile.
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final mockCredential = MockUserCredential();
      when(
        () => mockAuthRepo.signUp(any(), any(), any()),
      ).thenAnswer((_) async => mockCredential);

      await tester.pumpWidget(
        createTestWidgetWithDatabase(firebaseAuth: mockAuth, database: db),
      );

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
      final confirmPwField = find.widgetWithText(
        TextFormField,
        'Repeat password',
      );
      await tester.ensureVisible(confirmPwField);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(confirmPwField, 'password123');

      // Agree to terms
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Acknowledge offline warning if displayed
      final offlineCheckbox = find.byType(CheckboxListTile);
      if (tester.widgetList(offlineCheckbox).isNotEmpty) {
        await tester.tap(offlineCheckbox.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      final signUpButton = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(signUpButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(signUpButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      verify(
        () => mockRouter.push(any(that: isA<OnboardingRoute>())),
      ).called(1);
    });

    testWidgets('Google sign-in button triggers signInWithGoogle', (
      tester,
    ) async {
      final mockCredential = MockUserCredential();
      final mockAuthForGoogle = MockFirebaseAuth();
      final mockUser = MockUser();
      final db = UserDatabase(NativeDatabase.memory());

      addTearDown(() async => db.close());

      when(
        () => mockAuthRepo.signInWithGoogle(),
      ).thenAnswer((_) async => mockCredential);
      when(() => mockAuthForGoogle.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-uid');

      // Suppress provider exceptions from auth state notifier
      // since the full cloud-born flow requires Firebase.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('ProviderException') ||
            msg.contains('Firebase') ||
            msg.contains('core/no-app'))
          return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        createTestWidgetWithDatabase(
          firebaseAuth: mockAuthForGoogle,
          database: db,
        ),
      );

      final googleButton = find.text('Sign up with Google');
      await tester.ensureVisible(googleButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(googleButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Verify the sign-in was at least attempted
      verify(() => mockAuthRepo.signInWithGoogle()).called(1);
    });
  });
}
