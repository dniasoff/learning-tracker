import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart'
    show userDatabaseProvider;
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    as auth_state_mod;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/signup_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockStackRouter mockRouter;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(const OnboardingRoute());
    registerFallbackValue(SignupRoute());
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockRouter = MockStackRouter();
    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockRouter.push(any())).thenAnswer((_) async => null);
    when(() => mockRouter.replace(any())).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        home: StackRouterScope(
          controller: mockRouter,
          stateHash: 0,
          child: const SignupScreen(),
        ),
      ),
    );
  }

  Widget createTestWidgetWithDatabase({
    required UserDatabase database,
    bool online = true,
  }) {
    final testRegistry = DeviceRegistryDatabase(NativeDatabase.memory());
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        userDatabaseProvider.overrideWithValue(database),
        deviceRegistryProvider.overrideWithValue(testRegistry),
        auth_state_mod.authStateProvider.overrideWithValue(
          const AuthState.signedOut(),
        ),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
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
          child: const SignupScreen(),
        ),
      ),
    );
  }

  group('SignupScreen Widget Tests', () {
    testWidgets('displays email and password fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Create Password'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
    });

    testWidgets('displays Create Account title and Sign Up CTA', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('displays Google Sign-In button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Sign Up with Google'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final button = find.widgetWithText(FilledButton, 'Sign Up');
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

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test');
      await tester.enterText(fields.at(1), 'invalid-email');
      await tester.enterText(fields.at(2), '123456');
      final invalidEmailButton = find.widgetWithText(FilledButton, 'Sign Up');
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

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), '12345');
      final shortPwButton = find.widgetWithText(FilledButton, 'Sign Up');
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

      expect(find.text('OR'), findsOneWidget);
    });

    testWidgets('offline stream shows local warning and offline CTA', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());

      await tester.pumpWidget(
        createTestWidgetWithDatabase(database: db, online: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('no cloud backup'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create Offline Account'),
        findsOneWidget,
      );
    });

    testWidgets('Google sign-in button triggers signInWithGoogle', (
      tester,
    ) async {
      const mockUser = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
        emailVerified: true,
        providers: ['google.com'],
      );
      final db = UserDatabase(NativeDatabase.memory());

      addTearDown(() async => db.close());

      when(() => mockAuthRepo.signInWithGoogle()).thenAnswer((_) async {});
      when(() => mockAuthRepo.currentUser).thenReturn(mockUser);

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

      await tester.pumpWidget(createTestWidgetWithDatabase(database: db));

      final googleButton = find.text('Sign Up with Google');
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
