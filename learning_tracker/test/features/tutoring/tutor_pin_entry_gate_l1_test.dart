// L1 behaviour tests for TutorPinEntryGate (W6.5 — FR-5.4)
//
// Covers:
//   • When PIN is set → PIN entry UI shown (not setup screen)
//   • When no PIN is set → delegates to TutorPinSetupScreen inline
//   • Loading state → shows CircularProgressIndicator
//   • Error state → shows tutorPinErrorPrefix text
//   • Correct PIN → calls onPinVerified callback
//   • Wrong PIN → shows tutorPinIncorrect error; remains gated
//   • Lockout result → shows tutorPinLockedOut message; remains gated
//   • Cancel / close button → calls onCancel callback
//   • Forgot PIN link → present (navigates to reset flow)
//   • profileId keys on the TUTOR's own profile (C1): pins namespace is
//     profile_{tutorOwnProfileId}_tutor_pin_hash, NOT the talmid's id
//   • RTL (he) variant renders without overflow/crash

@Tags(['l1', 'tutoring', 'tutor_pin_entry_gate'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTutorPinService extends Mock implements TutorPinService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

// ── Constants ─────────────────────────────────────────────────────────────────

/// The TUTOR's own learner-profile ID (C1: the PIN namespace).
/// This must be distinct from any talmid profile ID to verify the gate
/// keys on the right namespace.
const int _kTutorProfileId = 7;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds the canonical pump harness for [TutorPinEntryGate].
///
/// [pinIsSet]       — the AsyncValue<bool> returned by [tutorPinIsSetProvider].
/// [mockService]    — the [TutorPinService] stub; overrides [tutorPinServiceProvider].
/// [onPinVerified]  — callback invoked on successful PIN entry.
/// [onCancel]       — callback invoked on close/cancel.
/// [locale]         — defaults to English; pass `const Locale('he')` for RTL.
Widget _buildHarness({
  required AsyncValue<bool> pinIsSet,
  required _MockTutorPinService mockService,
  required VoidCallback onPinVerified,
  required VoidCallback onCancel,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      tutorPinServiceProvider.overrideWithValue(mockService),
      tutorPinIsSetProvider(_kTutorProfileId).overrideWith(
        (_) async => pinIsSet.when(
          data: (v) => v,
          loading: () async {
            // Return a never-completing future to stay in loading state.
            await Future<bool>.delayed(const Duration(minutes: 10));
            return false;
          },
          error: (e, st) => Error.throwWithStackTrace(e, st),
        ),
      ),
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
      home: TutorPinEntryGate(
        profileId: _kTutorProfileId,
        onPinVerified: onPinVerified,
        onCancel: onCancel,
      ),
    ),
  );
}

/// Types one digit into the PIN field at [index] (0-based).
Future<void> _enterDigit(WidgetTester tester, int index, String digit) async {
  final field = find.byType(TextField).at(index);
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, digit);
  await tester.pump();
}

/// Enters a 4-digit PIN via the 4 TextField slots.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'pin must be exactly 4 digits');
  for (var i = 0; i < 4; i++) {
    await _enterDigit(tester, i, pin[i]);
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// Disposes all widgets cleanly to avoid stream/timer leaks after each test.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Helper to set a standard view size.
  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ── Loading state ──────────────────────────────────────────────────────────

  group('TutorPinEntryGate — loading state', () {
    testWidgets('shows CircularProgressIndicator while PIN check is pending', (
      tester,
    ) async {
      setViewSize(tester);

      // Use a completer so the provider never resolves during the test.
      final completer = Completer<bool>();
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorPinServiceProvider.overrideWithValue(mockService),
            tutorPinIsSetProvider(
              _kTutorProfileId,
            ).overrideWith((_) => completer.future),
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
            home: TutorPinEntryGate(
              profileId: _kTutorProfileId,
              onPinVerified: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pump(); // Let Riverpod start the async provider.

      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      expect(find.byType(TextField), findsNothing);

      // Complete the future so cleanup can proceed.
      completer.complete(true);
      await tester.pump(const Duration(seconds: 1));
      await _teardown(tester);
    });
  });

  // ── Error state ────────────────────────────────────────────────────────────

  group('TutorPinEntryGate — error state', () {
    testWidgets('shows error text when PIN check throws', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      // retry: (_, __) => null prevents Riverpod from retrying the failing
      // provider so the error state is stable and .when(error:) fires.
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            tutorPinServiceProvider.overrideWithValue(mockService),
            tutorPinIsSetProvider(
              _kTutorProfileId,
            ).overrideWith((_) async => throw Exception('storage unavailable')),
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
            home: TutorPinEntryGate(
              profileId: _kTutorProfileId,
              onPinVerified: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // tutorPinErrorPrefix('Failed to save. Please try again.') renders
      // 'Error: Failed to save. Please try again.' — no raw exception.
      expect(
        find.textContaining('Error:'),
        findsAtLeastNWidgets(1),
        reason: 'tutorPinErrorPrefix must appear when provider throws',
      );
      expect(find.byType(TextField), findsNothing);
      await _teardown(tester);
    });

    // R6-7 regression: raw exception must NOT leak to the user-facing text.
    testWidgets(
      'R6-7: error state does not expose raw exception string to user',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();

        await tester.pumpWidget(
          ProviderScope(
            retry: (_, __) => null,
            overrides: [
              tutorPinServiceProvider.overrideWithValue(mockService),
              tutorPinIsSetProvider(
                _kTutorProfileId,
              ).overrideWith((_) async => throw Exception('SECRET_DB_DETAIL')),
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
              home: TutorPinEntryGate(
                profileId: _kTutorProfileId,
                onPinVerified: () {},
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('SECRET_DB_DETAIL'),
          findsNothing,
          reason:
              'Raw exception message must not be visible to the user '
              '(R6-7 regression guard)',
        );

        await _teardown(tester);
      },
    );
  });

  // ── No PIN set → delegates to setup screen ─────────────────────────────────

  group('TutorPinEntryGate — no PIN set → shows setup screen', () {
    testWidgets('renders TutorPinSetupScreen when PIN is not set', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(false),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // TutorPinSetupScreen appBar title is "Set Tutor PIN"
      expect(
        find.text('Set Tutor PIN'),
        findsAtLeastNWidgets(1),
        reason:
            'When no PIN is set the gate must show the setup screen with '
            '"Set Tutor PIN" title',
      );
      // No PIN entry heading shown when on setup screen
      expect(find.text('Enter your Tutor PIN'), findsNothing);

      await _teardown(tester);
    });
  });

  // ── PIN is set → PIN entry UI ──────────────────────────────────────────────

  group('TutorPinEntryGate — PIN is set → shows PIN entry', () {
    testWidgets('renders AppBar title "Tutor PIN" when PIN is set', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // AppBar title from tutorPinAppBarTitle = 'Tutor PIN'
      expect(
        find.text('Tutor PIN'),
        findsAtLeastNWidgets(1),
        reason: 'AppBar title must be "Tutor PIN" when PIN is set',
      );
      await _teardown(tester);
    });

    testWidgets('shows l10n heading "Enter your Tutor PIN"', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Enter your Tutor PIN'),
        findsOneWidget,
        reason: 'tutorPinEntryHeading must be visible',
      );
      await _teardown(tester);
    });

    testWidgets('shows body text from tutorPinEntryBody', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Enter your 4-digit Tutor PIN to access this profile.'),
        findsOneWidget,
        reason: 'tutorPinEntryBody must be visible',
      );
      await _teardown(tester);
    });

    testWidgets('shows 4 PIN digit TextField slots', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(TextField),
        findsNWidgets(4),
        reason: 'PinEntryWidget must render 4 digit slots',
      );
      await _teardown(tester);
    });

    testWidgets('shows lock_person_rounded icon', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('shows close button that invokes onCancel when tapped', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      var cancelCalled = false;

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () => cancelCalled = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(
        cancelCalled,
        isTrue,
        reason: 'Tapping the close button must invoke onCancel',
      );
      await _teardown(tester);
    });

    testWidgets('shows "Forgot your Tutor PIN?" affordance', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Forgot your Tutor PIN?'),
        findsOneWidget,
        reason: 'tutorPinForgot link must be visible',
      );
      await _teardown(tester);
    });
  });

  // ── Correct PIN → unlocks / calls onPinVerified ────────────────────────────

  group('TutorPinEntryGate — correct PIN → unlocks', () {
    testWidgets(
      'entering correct PIN calls verifyTutorPin with TUTOR profile id and triggers onPinVerified',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var pinVerifiedCalled = false;
        int? capturedProfileId;

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((invocation) async {
          capturedProfileId = invocation.namedArguments[#profileId] as int;
          return const TutorPinSuccess();
        });

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () => pinVerifiedCalled = true,
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // C1 key assertion: service called with the TUTOR's own profileId
        expect(
          capturedProfileId,
          _kTutorProfileId,
          reason:
              'C1: verifyTutorPin must be called with the TUTOR own profile id '
              '($_kTutorProfileId), not a talmid id',
        );
        expect(
          pinVerifiedCalled,
          isTrue,
          reason: 'onPinVerified must be called on TutorPinSuccess',
        );

        verify(
          () => mockService.verifyTutorPin(
            profileId: _kTutorProfileId,
            rawPin: '1234',
          ),
        ).called(1);

        await _teardown(tester);
      },
    );

    testWidgets(
      'shows CircularProgressIndicator while verifying (in-flight state)',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final completer = Completer<TutorPinResult>();

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () {},
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '5678');
        await tester.pump(); // Starts async; doesn't resolve yet.

        // In-flight: spinner shown, PIN fields hidden
        expect(
          find.byType(CircularProgressIndicator),
          findsAtLeastNWidgets(1),
          reason: 'Spinner must show while verifyTutorPin is in flight',
        );

        // Complete so cleanup succeeds.
        completer.complete(const TutorPinSuccess());
        await tester.pump(const Duration(seconds: 1));
        await _teardown(tester);
      },
    );
  });

  // ── Wrong PIN → error + remains gated ─────────────────────────────────────

  group('TutorPinEntryGate — wrong PIN → error shown, remains gated', () {
    testWidgets(
      'TutorPinIncorrect: shows tutorPinIncorrect message and remains on entry screen',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var pinVerifiedCalled = false;

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((_) async => const TutorPinIncorrect());

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () => pinVerifiedCalled = true,
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '9999');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsAtLeastNWidgets(1),
          reason: 'tutorPinIncorrect l10n text must appear on wrong PIN',
        );
        expect(
          pinVerifiedCalled,
          isFalse,
          reason: 'onPinVerified must NOT be called on wrong PIN',
        );
        // Gate still shows the PIN entry heading (not setup screen)
        expect(find.text('Enter your Tutor PIN'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets('TutorPinValidationError: shows the custom error message', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      when(
        () => mockService.verifyTutorPin(
          profileId: any(named: 'profileId'),
          rawPin: any(named: 'rawPin'),
        ),
      ).thenAnswer(
        (_) async =>
            const TutorPinValidationError(message: 'Custom validation msg'),
      );

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '0000');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Custom validation msg'),
        findsAtLeastNWidgets(1),
        reason: 'TutorPinValidationError.message must appear as error text',
      );
      await _teardown(tester);
    });
  });

  // ── Lockout after N attempts ───────────────────────────────────────────────

  group('TutorPinEntryGate — lockout message', () {
    testWidgets(
      'TutorPinLockedOut: shows tutorPinLockedOut message with minutes and remains gated',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var pinVerifiedCalled = false;

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((_) async => const TutorPinLockedOut(remainingMinutes: 5));

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () => pinVerifiedCalled = true,
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '1111');
        await tester.pump(const Duration(seconds: 1));

        // tutorPinLockedOut(5) = 'Too many attempts. Locked for 5 minute(s).'
        expect(
          find.textContaining('Too many attempts'),
          findsAtLeastNWidgets(1),
          reason:
              'tutorPinLockedOut message must appear when service returns lockout',
        );
        expect(
          find.textContaining('5'),
          findsAtLeastNWidgets(1),
          reason: 'Lockout message must include the remaining minutes count',
        );
        expect(
          pinVerifiedCalled,
          isFalse,
          reason: 'onPinVerified must NOT be called when locked out',
        );
        // Gate remains on PIN entry screen
        expect(find.text('Enter your Tutor PIN'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets(
      'multiple wrong-PIN attempts each show the error and remain gated',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var verifyCallCount = 0;

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((_) async {
          verifyCallCount++;
          if (verifyCallCount < 3) {
            return const TutorPinIncorrect();
          }
          return const TutorPinLockedOut(remainingMinutes: 10);
        });

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () {},
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Attempt 1 — incorrect
        await _enterPin(tester, '2222');
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsAtLeastNWidgets(1),
        );

        // Attempt 2 — incorrect again
        await _enterPin(tester, '3333');
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsAtLeastNWidgets(1),
        );

        // Attempt 3 — triggers lockout
        await _enterPin(tester, '4444');
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.textContaining('Too many attempts'),
          findsAtLeastNWidgets(1),
          reason: 'After 3 bad attempts the lockout message must appear',
        );
        expect(verifyCallCount, 3);

        await _teardown(tester);
      },
    );
  });

  // ── C1: Gate keys on TUTOR own profile id, NOT talmid ─────────────────────

  group('TutorPinEntryGate — C1 profile id namespace', () {
    testWidgets(
      'verifyTutorPin is called with the tutor own profileId (not any talmid id)',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final capturedProfileIds = <int>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((invocation) async {
          capturedProfileIds.add(invocation.namedArguments[#profileId] as int);
          return const TutorPinSuccess();
        });

        // profileId=7 is the tutor's own id. Pass it to the gate directly.
        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () {},
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '5555');
        await tester.pump(const Duration(seconds: 1));

        expect(
          capturedProfileIds,
          everyElement(equals(_kTutorProfileId)),
          reason:
              'C1: the PIN namespace must use the TUTOR own profile id '
              '($_kTutorProfileId); a talmid id would be different',
        );
        await _teardown(tester);
      },
    );

    testWidgets('tutorPinIsSetProvider is called with the tutor own profileId', (
      tester,
    ) async {
      // This test verifies the gate passes widget.profileId (tutorOwnProfileId)
      // to the tutorPinIsSetProvider. We use a spy override that captures
      // whether it was reached at all (its arg must match _kTutorProfileId).
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      var providerCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorPinServiceProvider.overrideWithValue(mockService),
            tutorPinIsSetProvider(_kTutorProfileId).overrideWith((_) async {
              providerCalled = true;
              return true;
            }),
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
            home: TutorPinEntryGate(
              profileId: _kTutorProfileId,
              onPinVerified: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        providerCalled,
        isTrue,
        reason:
            'tutorPinIsSetProvider must be called with the tutor own profileId $_kTutorProfileId',
      );
      await _teardown(tester);
    });
  });

  // ── Reset entry point ──────────────────────────────────────────────────────

  group('TutorPinEntryGate — reset entry point', () {
    testWidgets(
      'tapping "Forgot your Tutor PIN?" navigates to reset screen (no crash)',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final mockAuthRepo = _MockAuthRepository();

        // TutorPinResetScreen reads authRepositoryProvider.currentUser.
        when(() => mockAuthRepo.currentUser).thenReturn(
          const AppUser(
            uid: 'tutor-uid',
            email: 'tutor@example.com',
            displayName: 'Test Tutor',
            emailVerified: true,
            providers: ['password'],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tutorPinServiceProvider.overrideWithValue(mockService),
              authRepositoryProvider.overrideWithValue(mockAuthRepo),
              tutorPinIsSetProvider(
                _kTutorProfileId,
              ).overrideWith((_) async => true),
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
              home: TutorPinEntryGate(
                profileId: _kTutorProfileId,
                onPinVerified: () {},
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Forgot your Tutor PIN?'), findsOneWidget);
        await tester.tap(find.text('Forgot your Tutor PIN?'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // TutorPinResetScreen has AppBar title 'Reset Tutor PIN'
        expect(
          find.text('Reset Tutor PIN'),
          findsOneWidget,
          reason:
              'Tapping the forgot-PIN link must push TutorPinResetScreen '
              '(AppBar title "Reset Tutor PIN")',
        );

        await _teardown(tester);
      },
    );
  });

  // ── RTL (Hebrew) variant ───────────────────────────────────────────────────

  group('TutorPinEntryGate — Hebrew (RTL) variant', () {
    testWidgets('he locale: renders PIN entry screen without overflow or crash', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        _buildHarness(
          pinIsSet: const AsyncValue.data(true),
          mockService: mockService,
          onPinVerified: () {},
          onCancel: () {},
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No RenderFlex overflow exceptions — just assert key structural widgets.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets(
      'he locale: no PIN set → delegates to setup screen without crash',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(false),
            mockService: mockService,
            onPinVerified: () {},
            onCancel: () {},
            locale: const Locale('he'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // TutorPinSetupScreen should render without crash under RTL.
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );
  });
}
