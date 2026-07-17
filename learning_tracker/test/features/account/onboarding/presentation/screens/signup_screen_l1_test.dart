// L1 widget tests for SignupScreen
//
// Covers:
//   • Render — form fields + labels + CTA button present
//   • Validation — empty fields, invalid email, short password, missing name
//   • Online state — cloud card, Sign Up CTA, OR divider, Google button
//   • Offline state — warning cards, checkbox, "Create Offline Account" CTA
//     (Google button + OR divider absent offline)
//   • Prefilled name / email from route args
//   • Password visibility toggle
//   • Submit → loading spinner shown, fields disabled
//   • Cloud signup path — happy path: calls signUp + sendEmailVerification
//     + signOut; shows snackbar; navigates to SignInRoute
//   • Cloud signup path — DuplicateEmailException: shows snackbar error
//   • Cloud signup path — generic error: shows snackbar error
//   • Cloud signup path — [email-already-in-use] Firebase code: mapped message
//   • Offline path — credential-less explicit "Create Offline Account"
//   • "Log In" link — not tappable while loading
//   • He-locale smoke — renders without overflow in Hebrew RTL locale
@Tags(['l1', 'signup', 'account'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/signup_screen.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mock_repositories.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds the widget under test.
///
/// [online] controls the connectivity stream override.
/// [authRepo] defaults to a stub that records calls.
Widget _buildApp({
  _MockStackRouter? router,
  MockAuthRepository? authRepo,
  bool online = true,
  Locale locale = const Locale('en'),
  String? prefilledName,
  String? prefilledEmail,
}) {
  final r = router ?? _MockStackRouter();
  final auth = authRepo ?? MockAuthRepository();

  // Safe defaults so un-expected calls don't crash.
  when(() => r.replace(any())).thenAnswer((_) async => null);
  when(
    () => r.push<Object?>(any(), onFailure: any(named: 'onFailure')),
  ).thenAnswer((_) async => null);
  when(() => r.replaceAll(any())).thenAnswer((_) async => []);
  when(() => r.canPop()).thenReturn(false);
  when(() => auth.currentUser).thenReturn(null);

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: r,
        stateHash: 0,
        child: Scaffold(
          body: SignupScreen(
            prefilledName: prefilledName,
            prefilledEmail: prefilledEmail,
          ),
        ),
      ),
    ),
  );
}

/// Types valid credentials into the three form fields.
Future<void> _fillValidCredentials(
  WidgetTester tester, {
  String name = 'Test User',
  String email = 'test@example.com',
  String password = 'password123',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(const SignInRoute());
    registerFallbackValue(const OnboardingRoute());
  });

  // ── Render ─────────────────────────────────────────────────────────────────

  testWidgets('renders Create Account heading', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Create Account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'renders Display Name, Email Address and Create Password labels',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Create Password'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('renders three TextFormFields', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TextFormField), findsNWidgets(3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Online state UI ────────────────────────────────────────────────────────

  testWidgets('online: shows Sign Up CTA button', (tester) async {
    await tester.pumpWidget(_buildApp(online: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.widgetWithText(FilledButton, 'Sign Up'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('online: shows cloud account info card', (tester) async {
    await tester.pumpWidget(_buildApp(online: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining('Cloud account'),
      findsOneWidget,
      reason: 'cloud card should describe cloud backup',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('online: shows OR divider between email and Google sections', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(online: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('OR'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('online: shows Sign Up with Google button', (tester) async {
    await tester.pumpWidget(_buildApp(online: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign Up with Google'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('online: shows "Already exploring?" rich-text with Log In span', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(online: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // "Log In" is a TextSpan inside a RichText widget — find via widget predicate
    final richTextWithLogIn = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      return w.text.toPlainText().contains('Log In');
    });
    expect(
      richTextWithLogIn,
      findsOneWidget,
      reason: '"Log In" RichText span must be present in online mode',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Offline state UI ───────────────────────────────────────────────────────

  testWidgets('offline: CTA button reads "Create Offline Account"', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(online: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.widgetWithText(FilledButton, 'Create Offline Account'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('offline: shows local-only warning cards', (tester) async {
    await tester.pumpWidget(_buildApp(online: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining('Local account only'),
      findsOneWidget,
      reason: 'offline warning card must be shown when offline',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('offline: credential-less — no checkbox and no email/password/'
      'name fields; shows explanation + retry', (tester) async {
    await tester.pumpWidget(_buildApp(online: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Offline accounts collect nothing: no ack checkbox, no input fields.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    // The explicit-offline explanation + retry affordance are shown.
    expect(find.textContaining('offline account'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Retry connection'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('offline: Google button and OR divider are NOT shown', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(online: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign Up with Google'), findsNothing);
    expect(find.text('OR'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('loading (probe in flight): defaults to the offline variant — '
      'coral warning + Create Offline Account, no Google button / OR divider '
      '(offline-until-proven-online)', (tester) async {
    // A never-emitting stream keeps connectivity in its loading state so we
    // exercise the orElse fallback (lastKnownOnline, default false).
    debugResetLastKnownOnline();
    addTearDown(debugResetLastKnownOnline);

    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(() => router.replaceAll(any())).thenAnswer((_) async => []);
    when(() => router.canPop()).thenReturn(false);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream<bool>.empty(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const Scaffold(body: SignupScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.widgetWithText(FilledButton, 'Create Offline Account'),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Sign Up with Google'), findsNothing);
    expect(find.text('OR'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Prefilled args ─────────────────────────────────────────────────────────

  testWidgets('prefilledName populates Display Name field on init', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(prefilledName: 'Prefilled Scholar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, contains('Prefilled Scholar'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('prefilledEmail populates Email Address field on init', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(prefilledEmail: 'prefilled@example.com'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Check that the email field shows the prefilled value
    expect(
      find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.text('prefilled@example.com'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Validation ─────────────────────────────────────────────────────────────

  testWidgets('tapping Sign Up with empty fields shows all validation errors', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Display name is required'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('invalid email format shows validation error', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'not-an-email');
    await tester.enterText(fields.at(2), 'password123');
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Please enter a valid email address'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('password shorter than 6 chars shows "at least 6 characters"', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), '12345');
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('empty display name shows "Display name is required"', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final fields = find.byType(TextFormField);
    // Leave name empty, fill rest
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Display name is required'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Password visibility toggle ─────────────────────────────────────────────

  testWidgets(
    'password field starts with lock icon and toggle shows visibility icon',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Initially the lock icon is shown (password obscured)
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsNothing);

      // Tap the lock icon to reveal
      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pump();

      // After toggle, the visibility icon appears
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('visibility icon changes from lock to visibility after toggle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Submit → loading state ─────────────────────────────────────────────────

  testWidgets(
    'tapping Sign Up with valid data shows CircularProgressIndicator',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      // Block the signUp call so the loading state persists
      final completer = Completer<void>();
      when(
        () => auth.signUp(any(), any(), any()),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      // Loading spinner should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Button text is gone
      expect(find.text('Sign Up'), findsNothing);

      completer.complete();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('while loading, form fields are disabled', (tester) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);

    final completer = Completer<void>();
    when(
      () => auth.signUp(any(), any(), any()),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    // All fields should be disabled
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    for (final field in fields) {
      expect(
        field.enabled,
        isFalse,
        reason: 'form fields must be disabled while loading',
      );
    }

    completer.complete();
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Cloud signup — happy path ──────────────────────────────────────────────

  testWidgets(
    'cloud signup happy path: calls signUp + sendEmailVerification + signOut',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signUp(any(), any(), any())).thenAnswer((_) async {});
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final router = _MockStackRouter();
      when(() => router.replace(any())).thenAnswer((_) async => null);
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);
      when(() => router.replaceAll(any())).thenAnswer((_) async => []);
      when(() => router.canPop()).thenReturn(false);

      await tester.pumpWidget(
        _buildApp(online: true, authRepo: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => auth.signUp('test@example.com', 'password123', 'Test User'),
      ).called(1);
      verify(() => auth.sendEmailVerification()).called(1);
      verify(() => auth.signOut()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('cloud signup happy path: shows verification email snackbar', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.signUp(any(), any(), any())).thenAnswer((_) async {});
    when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});

    final router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(() => router.replaceAll(any())).thenAnswer((_) async => []);
    when(() => router.canPop()).thenReturn(false);

    await tester.pumpWidget(
      _buildApp(online: true, authRepo: auth, router: router),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Snackbar with verification message
    expect(find.textContaining('Verification email sent'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'cloud signup happy path: navigates to SignInRoute via router.replace',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signUp(any(), any(), any())).thenAnswer((_) async {});
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final router = _MockStackRouter();
      when(() => router.replace(any())).thenAnswer((_) async => null);
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);
      when(() => router.replaceAll(any())).thenAnswer((_) async => []);
      when(() => router.canPop()).thenReturn(false);

      await tester.pumpWidget(
        _buildApp(online: true, authRepo: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // router.replace(SignInRoute()) is called
      verify(() => router.replace(any())).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Cloud signup — DuplicateEmailException ─────────────────────────────────

  testWidgets(
    'cloud signup: DuplicateEmailException shows "account already exists" snackbar',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.signUp(any(), any(), any()),
      ).thenThrow(const DuplicateEmailException('test@example.com'));

      await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('account already exists'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Cloud signup — InvalidInputException ──────────────────────────────────

  testWidgets(
    'cloud signup: InvalidInputException resolves code via AppLocalizations '
    '(AUD-account-17) — never shows the raw English reason',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signUp(any(), any(), any())).thenThrow(
        const InvalidInputException(
          'email',
          InvalidInputCode.invalidEmail,
          'invalid format',
        ),
      );

      await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The localized message shows — NOT the raw, log-only `reason` string.
      expect(
        find.textContaining('Please enter a valid email address'),
        findsOneWidget,
      );
      expect(find.textContaining('invalid format'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Cloud signup — Firebase error code mapping ─────────────────────────────

  testWidgets(
    'cloud signup: [email-already-in-use] error maps to friendly message',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signUp(any(), any(), any())).thenThrow(
        Exception(
          '[email-already-in-use] The email address is already in use.',
        ),
      );

      await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('account already exists'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('cloud signup: [weak-password] error maps to friendly message', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.signUp(any(), any(), any())).thenThrow(
      Exception('[weak-password] Password should be at least 6 characters.'),
    );

    await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Password is too weak'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('cloud signup: [invalid-email] error maps to friendly message', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.signUp(any(), any(), any())).thenThrow(
      Exception('[invalid-email] The email address is badly formatted.'),
    );

    await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('valid email address'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // AUD-account-12 (narrowed on verify): a user whose email already has a
  // password-based Firebase account taps "Sign Up" using that same address
  // — Firebase reports account-exists-with-different-credential. Pre-fix,
  // this fell to the generic "Account creation failed" fallback with zero
  // guidance to use the existing password. _mapAuthError is shared between
  // the password and Google sign-up paths, so exercising it through the
  // already-mocked signUp() call site proves the mapping directly.
  testWidgets(
    'cloud signup: [account-exists-with-different-credential] error maps '
    'to an actionable message (not the generic fallback)',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signUp(any(), any(), any())).thenThrow(
        Exception('[account-exists-with-different-credential] collision'),
      );

      await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _fillValidCredentials(tester);

      final button = find.widgetWithText(FilledButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('already has a password'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('cloud signup: generic error shows fallback snackbar message', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.signUp(any(), any(), any()),
    ).thenThrow(Exception('something unexpected'));

    await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final button = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // fallback message contains "Account creation failed"
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'a snackbar must appear on any unexpected signup error',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // (The offline "acknowledgement gate" was removed: offline accounts are now
  // credential-less and created via an explicit "Create Offline Account"
  // button — there is no checkbox/email/password to gate. See the offline
  // credential-less UI test above.)

  // ── Loading state disables Google button ─────────────────────────────────

  testWidgets('Sign Up with Google button disabled while loading', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);

    // Block signUp to hold loading state
    final completer = Completer<void>();
    when(
      () => auth.signUp(any(), any(), any()),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_buildApp(online: true, authRepo: auth));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillValidCredentials(tester);

    final signUpButton = find.widgetWithText(FilledButton, 'Sign Up');
    await tester.ensureVisible(signUpButton);
    await tester.pump();
    await tester.tap(signUpButton);
    await tester.pump();

    // Google button should be disabled while loading
    final googleButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(
      googleButton.onPressed,
      isNull,
      reason: 'Google button must be disabled while loading',
    );

    completer.complete();
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── He-locale smoke ────────────────────────────────────────────────────────

  testWidgets('Hebrew locale: form renders without overflow or crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(locale: const Locale('he'), online: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Core elements still present in RTL — now rendered via l10n (iter9 fix).
    // Hebrew ARB value for signUpTitle is "צור חשבון".
    expect(find.text('צור חשבון'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Hebrew locale offline: warning cards render without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(locale: const Locale('he'), online: false),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Offline warning text must still be shown in RTL — now via l10n (iter9 fix).
    // Hebrew ARB value for authModeLocalTitle contains "חשבון מקומי בלבד".
    expect(find.textContaining('חשבון מקומי בלבד'), findsOneWidget);
    // Credential-less offline: no acknowledgement checkbox, no input fields.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
