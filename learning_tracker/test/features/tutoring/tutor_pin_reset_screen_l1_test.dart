// L1 widget test for TutorPinResetScreen (W6.6 — FR-5.5)
//
// Verifies:
//   1. Confirm step renders expected l10n labels and email address.
//   2. Send button is present and tappable when not loading.
//   3. Send button shows CircularProgressIndicator while sending.
//   4. Successful send: transitions to emailSent step.
//   5. Error on send: error message appears.
//   6. No-email edge case: shows no-email error message.
//   7. emailSent step: shows check-email heading, body with email, and Set new PIN button.
//   8. "Set new PIN" calls onResetComplete callback.

@Tags(['needs_flutter', 'tutor_pin'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_reset_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTutorPinService extends Mock implements TutorPinService {}

// ── Helpers ──────────────────────────────────────────────────────────────────

const _kProfileId = 42;
const _kEmail = 'tutor@example.com';

AppUser _fakeUser({String? email = _kEmail}) => AppUser(
  uid: 'uid-1',
  email: email,
  displayName: 'Test Tutor',
  emailVerified: true,
  providers: const ['password'],
);

void main() {
  late _MockAuthRepository mockAuthRepo;
  late _MockTutorPinService mockPinService;
  late bool resetCompleteCalled;

  setUp(() {
    mockAuthRepo = _MockAuthRepository();
    mockPinService = _MockTutorPinService();
    resetCompleteCalled = false;
  });

  Widget buildSubject({AppUser? user, VoidCallback? onResetComplete}) {
    // Default: signed-in user with email.
    when(() => mockAuthRepo.currentUser).thenReturn(user ?? _fakeUser());

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        tutorPinServiceProvider.overrideWithValue(mockPinService),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TutorPinResetScreen(
          profileId: _kProfileId,
          onResetComplete: onResetComplete ?? () => resetCompleteCalled = true,
        ),
      ),
    );
  }

  // Teardown helper reused in each test.
  Future<void> tearDownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  // ── Test: confirm step — key labels present ──────────────────────────────

  testWidgets(
    'confirm step shows app-bar title, heading, email, and send button',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // App-bar title
      expect(find.text('Reset Tutor PIN'), findsOneWidget);

      // Heading
      expect(find.text('Reset your Tutor PIN'), findsOneWidget);

      // "We will send a reset link to:" label
      expect(find.text('We will send a reset link to:'), findsOneWidget);

      // Email displayed
      expect(find.text(_kEmail), findsOneWidget);

      // Hint about returning
      expect(
        find.text('After following the link, return here to create a new PIN.'),
        findsOneWidget,
      );

      // Send button label
      expect(find.text('Send reset email'), findsOneWidget);

      await tearDownWidget(tester);
    },
  );

  // ── Test: fallback when no email ─────────────────────────────────────────

  testWidgets('shows fallback email text when currentUser is null', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(user: _fakeUser(email: null)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Fallback text should appear in place of an email address
    expect(find.text('your account email'), findsOneWidget);

    await tearDownWidget(tester);
  });

  // ── Test: send button disabled while sending ─────────────────────────────

  testWidgets(
    'send button is disabled and shows CircularProgressIndicator while request is in flight',
    (tester) async {
      // Make sendPasswordResetEmail hang so we can observe intermediate state.
      final completer = Completer<void>();
      when(
        () => mockAuthRepo.sendPasswordResetEmail(_kEmail),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Tap send
      await tester.tap(find.text('Send reset email'));
      await tester.pump(); // Start processing

      // During inflight: spinner present, button text absent
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Send reset email'), findsNothing);

      // Complete the request so we can clean up
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tearDownWidget(tester);
    },
  );

  // ── Test: successful send → emailSent step ───────────────────────────────

  testWidgets('successful send transitions to emailSent step', (tester) async {
    when(
      () => mockAuthRepo.sendPasswordResetEmail(_kEmail),
    ).thenAnswer((_) async {});
    when(
      () => mockPinService.clearTutorPin(_kProfileId),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // emailSent step: heading
    expect(find.text('Check your email'), findsOneWidget);

    // emailSent step: body contains the email
    expect(find.textContaining(_kEmail), findsWidgets);

    // "Set new PIN" button present
    expect(find.text('Set new PIN'), findsOneWidget);

    // Old confirm-step heading gone
    expect(find.text('Reset your Tutor PIN'), findsNothing);

    // Verify clearTutorPin was called
    verify(() => mockPinService.clearTutorPin(_kProfileId)).called(1);

    await tearDownWidget(tester);
  });

  // ── Test: send failure → error message ──────────────────────────────────

  testWidgets('failed send shows error message and stays on confirm step', (
    tester,
  ) async {
    when(
      () => mockAuthRepo.sendPasswordResetEmail(_kEmail),
    ).thenThrow(Exception('network error'));

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Error message
    expect(
      find.text('Failed to send reset email. Please try again.'),
      findsOneWidget,
    );

    // Still on confirm step
    expect(find.text('Reset your Tutor PIN'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);

    await tearDownWidget(tester);
  });

  // ── Test: no-email → shows tutorPinResetNoEmail error ───────────────────

  testWidgets('tapping send without an email shows no-email error message', (
    tester,
  ) async {
    // User with no email address
    await tester.pumpWidget(
      buildSubject(
        user: const AppUser(
          uid: 'uid-nomail',
          email: null,
          displayName: 'No Email',
          emailVerified: false,
          providers: [],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    // The no-email error string
    expect(
      find.text(
        'No email address found for your account. '
        'Please sign in with a cloud account to use PIN reset.',
      ),
      findsOneWidget,
    );

    // sendPasswordResetEmail should NOT have been called
    verifyNever(() => mockAuthRepo.sendPasswordResetEmail(any()));

    await tearDownWidget(tester);
  });

  // ── Test: emailSent step — set new PIN calls onResetComplete ────────────

  testWidgets('"Set new PIN" button invokes onResetComplete callback', (
    tester,
  ) async {
    when(
      () => mockAuthRepo.sendPasswordResetEmail(_kEmail),
    ).thenAnswer((_) async {});
    when(
      () => mockPinService.clearTutorPin(_kProfileId),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Advance to emailSent step
    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Set new PIN'), findsOneWidget);
    expect(resetCompleteCalled, isFalse);

    await tester.tap(find.text('Set new PIN'));
    await tester.pump();

    expect(resetCompleteCalled, isTrue);

    await tearDownWidget(tester);
  });

  // ── Test: emailSent step icons rendered ─────────────────────────────────

  testWidgets('emailSent step shows mark_email_read icon', (tester) async {
    when(
      () => mockAuthRepo.sendPasswordResetEmail(_kEmail),
    ).thenAnswer((_) async {});
    when(
      () => mockPinService.clearTutorPin(_kProfileId),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify the success icon
    expect(find.byIcon(Icons.mark_email_read_rounded), findsOneWidget);

    // Confirm-step icon should be gone
    expect(find.byIcon(Icons.lock_reset_rounded), findsNothing);

    await tearDownWidget(tester);
  });

  // ── Test: confirm step shows lock_reset icon ─────────────────────────────

  testWidgets('confirm step shows lock_reset icon', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);

    await tearDownWidget(tester);
  });
}
