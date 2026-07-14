import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart'
    show userDatabaseProvider;
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/signup_screen.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
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
    // These tests assert the ONLINE signup variant (Sign Up CTA, Google button,
    // OR divider). The screen seeds its connectivity loading-window from the
    // process-wide lastKnownOnline cache (default offline); a stream override
    // alone doesn't update it, so seed it online here.
    debugSetLastKnownOnline(true);
  });

  tearDown(debugResetLastKnownOnline);

  Widget createTestWidget({Locale locale = const Locale('en')}) {
    return pumpApp(
      locale: locale,
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: const SignupScreen(),
      ),
    );
  }

  Widget createTestWidgetWithDatabase({
    required UserDatabase database,
    bool online = true,
    Locale locale = const Locale('en'),
  }) {
    final testRegistry = DeviceRegistryDatabase(NativeDatabase.memory());
    addTearDown(() async => testRegistry.close());
    return pumpApp(
      locale: locale,
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        userDatabaseProvider.overrideWithValue(database),
        deviceRegistryProvider.overrideWithValue(testRegistry),
        authStateProvider.overrideWithValue(const AuthState.signedOut()),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: const SignupScreen(),
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

  // ── iter9 l10n regression: signup screen strings must come from ARB ──────────
  //
  // Prior to the fix, all UI strings in SignupScreen were hardcoded English
  // literals. This group verifies that the l10n keys are wired up correctly
  // by checking that:
  //   • English locale renders the expected English ARB values.
  //   • Hebrew locale renders Hebrew ARB values (non-English strings appear,
  //     English literals are absent).
  group('iter9 l10n regression: signup screen strings localized', () {
    testWidgets(
      'English: title, subtitle, labels, CTA, OR divider come from l10n',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Title and subtitle from ARB keys signUpTitle / signUpSubtitle.
        expect(
          find.text('Create Account'),
          findsOneWidget,
          reason: 'signUpTitle must render via l10n',
        );
        expect(
          find.text('Create your free account'),
          findsOneWidget,
          reason: 'signUpSubtitle must render via l10n',
        );

        // Field labels from l10n.
        expect(
          find.text('Display Name'),
          findsOneWidget,
          reason: 'displayName label must come from l10n.displayName',
        );
        expect(
          find.text('Email Address'),
          findsOneWidget,
          reason: 'signUpEmailAddressLabel must render via l10n',
        );
        expect(
          find.text('Create Password'),
          findsOneWidget,
          reason: 'signUpPasswordLabel must render via l10n',
        );

        // CTA and OR divider.
        expect(
          find.text('Sign Up'),
          findsOneWidget,
          reason: 'signUpCta must render via l10n',
        );
        expect(
          find.text('OR'),
          findsOneWidget,
          reason: 'signUpOrDivider must render via l10n',
        );
        expect(
          find.text('Sign Up with Google'),
          findsOneWidget,
          reason: 'signUpGoogleCta must render via l10n',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Hebrew locale: key UI strings render in Hebrew, not English', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('he')));
      await tester.pump();

      // Hebrew ARB value for signUpTitle is "צור חשבון".
      expect(
        find.text('צור חשבון'),
        findsOneWidget,
        reason: 'iter9 l10n: signUpTitle must render in Hebrew locale',
      );
      // English literal must be absent.
      expect(
        find.text('Create Account'),
        findsNothing,
        reason:
            'iter9 l10n: hardcoded English "Create Account" must be absent in Hebrew',
      );

      // Hebrew ARB value for signUpCta is "הרשמה".
      expect(
        find.text('הרשמה'),
        findsOneWidget,
        reason: 'iter9 l10n: signUpCta must render in Hebrew locale',
      );
      expect(
        find.text('Sign Up'),
        findsNothing,
        reason:
            'iter9 l10n: hardcoded English "Sign Up" must be absent in Hebrew',
      );

      // Hebrew ARB value for signUpOrDivider is "או".
      expect(
        find.text('או'),
        findsOneWidget,
        reason: 'iter9 l10n: signUpOrDivider must render in Hebrew locale',
      );
      expect(
        find.text('OR'),
        findsNothing,
        reason: 'iter9 l10n: hardcoded English "OR" must be absent in Hebrew',
      );

      // Hebrew ARB value for signUpGoogleCta is "הרשמה עם גוגל".
      expect(
        find.text('הרשמה עם גוגל'),
        findsOneWidget,
        reason: 'iter9 l10n: signUpGoogleCta must render in Hebrew locale',
      );
      expect(
        find.text('Sign Up with Google'),
        findsNothing,
        reason:
            'iter9 l10n: hardcoded English "Sign Up with Google" must be absent in Hebrew',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'AUD-onboarding-03: Hebrew locale validation errors render in Hebrew, '
      'not English',
      (tester) async {
        await tester.pumpWidget(createTestWidget(locale: const Locale('he')));

        final button = find.widgetWithText(FilledButton, 'הרשמה');
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Hebrew ARB values for the three required-field validators.
        expect(
          find.text('נדרש אימייל'),
          findsOneWidget,
          reason: 'AUD-onboarding-03: authEmailRequired must render in Hebrew',
        );
        expect(
          find.text('נדרשת סיסמה'),
          findsOneWidget,
          reason:
              'AUD-onboarding-03: authPasswordRequired must render in Hebrew',
        );
        expect(
          find.text('נדרש שם תצוגה'),
          findsOneWidget,
          reason:
              'AUD-onboarding-03: authDisplayNameRequired must render in '
              'Hebrew',
        );

        // The old hardcoded English literals must be absent.
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Password is required'), findsNothing);
        expect(find.text('Display name is required'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Hebrew offline mode: local-only warning card renders in Hebrew', (
      tester,
    ) async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(() async => db.close());

      await tester.pumpWidget(
        createTestWidgetWithDatabase(
          database: db,
          online: false,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hebrew for authModeLocalTitle (unique substring for the title card).
      expect(
        find.textContaining('חשבון מקומי בלבד'),
        findsOneWidget,
        reason:
            'iter9 l10n: authModeLocalTitle must render in Hebrew for offline mode',
      );
      // Hebrew CTA for createOfflineAccount.
      expect(
        find.widgetWithText(FilledButton, 'צור חשבון לא מקוון'),
        findsOneWidget,
        reason:
            'iter9 l10n: createOfflineAccount CTA must render in Hebrew for offline mode',
      );
      // English literal must be absent.
      expect(
        find.text('Local account only: no cloud backup and no device sync.'),
        findsNothing,
        reason:
            'iter9 l10n: hardcoded English local-only warning must be absent in Hebrew',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
