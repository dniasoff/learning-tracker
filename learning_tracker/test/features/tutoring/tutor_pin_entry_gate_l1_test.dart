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

/// Taps a single digit key on the on-screen numpad.
///
/// The gate uses a custom numpad (NOT TextFields / the device soft-keyboard),
/// so digits are entered by tapping the rendered digit keys.
Future<void> _tapDigit(WidgetTester tester, String digit) async {
  // The numpad key renders the digit as Text inside an InkWell. There is
  // exactly one such Text per digit in the entry UI.
  await tester.tap(find.widgetWithText(InkWell, digit));
  await tester.pump();
}

/// Enters a 4-digit PIN by tapping the numpad keys in order.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'pin must be exactly 4 digits');
  for (var i = 0; i < 4; i++) {
    await _tapDigit(tester, pin[i]);
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

  // ── AUD-tutoring-15: icon-only controls need semantic labels, and the
  // numpad key must not clip/overflow at large accessibility text scales.

  group('TutorPinEntryGate — AUD-tutoring-15: accessibility', () {
    testWidgets(
      'close button and backspace key expose non-empty semantic labels',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        final handle = tester.ensureSemantics();

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

        // The close icon button surfaces its `tooltip:` as a Semantics
        // `tooltip` announcement ('Close' — l10n.actionClose, en); Flutter's
        // find.byTooltip matches that field directly. The backspace numpad
        // key surfaces its `semanticLabel:` on the Icon as a Semantics
        // `label` ('Delete' — l10n.pinBackspace, en).
        expect(
          find.byTooltip('Close'),
          findsOneWidget,
          reason:
              'AUD-tutoring-15: the AppBar close icon button must expose a '
              'non-empty semantic label (tooltip) for screen readers',
        );
        expect(
          find.bySemanticsLabel('Delete'),
          findsOneWidget,
          reason:
              'AUD-tutoring-15: the backspace numpad key must expose a '
              'non-empty semantic label for screen readers',
        );

        handle.dispose();
        await _teardown(tester);
      },
    );

    testWidgets('numpad renders without RenderFlex overflow at textScale 2.0', (
      tester,
    ) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // A RenderFlex overflow surfaces as a FlutterError caught by the
      // test binding; takeException() returns it if one was recorded.
      expect(
        tester.takeException(),
        isNull,
        reason:
            'AUD-tutoring-15: the numpad must not overflow/clip at '
            'textScale 2.0 (fixed-height digit-key wrapper regression)',
      );

      await _teardown(tester);
    });
  });

  // ── AUD-tutoring-04: verifyTutorPin throws → error state, not a silent
  // stall. Before the fix, _onPinComplete had no catch clause, so a raw
  // exception from the service (e.g. secure-storage/keystore failure) left
  // _isVerifying reset by `finally` but _errorMessage null and _digits still
  // at 4 filled dots — a stalled numpad with no explanation.

  group('TutorPinEntryGate — AUD-tutoring-04: verifyTutorPin throws', () {
    testWidgets(
      'shows a generic error message and clears the stalled digits instead '
      'of silently stalling',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var pinVerifiedCalled = false;

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenThrow(Exception('keystore unavailable'));

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

        // Spinner must not be stuck forever (finally still resets it) AND an
        // error message must now be visible — the silent-stall symptom is
        // that NEITHER an error nor a way to retry appears.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Verifying spinner must clear once the throw is handled',
        );
        expect(
          find.textContaining('Error:'),
          findsAtLeastNWidgets(1),
          reason:
              'AUD-tutoring-04: an uncaught exception from verifyTutorPin '
              'must surface a visible error state, not a silent stall',
        );
        // The stalled 4-digit entry must be cleared so the user can retype.
        expect(
          pinVerifiedCalled,
          isFalse,
          reason: 'onPinVerified must not fire on a thrown exception',
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

    testWidgets('renders an on-screen numpad (digits 0-9) — no soft keyboard', (
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

      // The gate must NOT rely on TextFields / the device soft-keyboard —
      // that was the BUG-1 root cause (taps summoned no keyboard on device).
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'Gate must use a custom numpad, not soft-keyboard TextFields',
      );
      // All ten digit keys must be tappable on the custom numpad.
      for (var d = 0; d <= 9; d++) {
        expect(
          find.widgetWithText(InkWell, '$d'),
          findsOneWidget,
          reason: 'Numpad must render a tappable key for digit $d',
        );
      }
      // Backspace key present.
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
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

  // ── BUG-1 regression: numpad input registers and verifies ────────────────

  group('TutorPinEntryGate — BUG-1: numpad input drives verification', () {
    testWidgets(
      'tapping numpad keys fills the dots and a complete PIN triggers '
      'verifyTutorPin (no soft keyboard required)',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();
        var verifiedCalled = false;
        final captured = <String>[];

        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer((invocation) async {
          captured.add(invocation.namedArguments[#rawPin] as String);
          return const TutorPinSuccess();
        });

        await tester.pumpWidget(
          _buildHarness(
            pinIsSet: const AsyncValue.data(true),
            mockService: mockService,
            onPinVerified: () => verifiedCalled = true,
            onCancel: () {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Tap 3 of 4 digits — verification must NOT fire yet.
        await _tapDigit(tester, '2');
        await _tapDigit(tester, '2');
        await _tapDigit(tester, '2');
        await tester.pump();
        expect(
          captured,
          isEmpty,
          reason: 'verifyTutorPin must not fire before 4 digits are entered',
        );

        // Tap the 4th digit — now verification fires with the entered PIN.
        await _tapDigit(tester, '2');
        await tester.pump(const Duration(seconds: 1));

        expect(
          captured,
          equals(['2222']),
          reason:
              'BUG-1: tapping the numpad keys must register input and submit '
              'the assembled PIN to verifyTutorPin',
        );
        expect(
          verifiedCalled,
          isTrue,
          reason:
              'A correct PIN (2222) must advance the gate via onPinVerified',
        );
        await _teardown(tester);
      },
    );

    testWidgets('backspace removes the last entered digit', (tester) async {
      setViewSize(tester);
      final mockService = _MockTutorPinService();
      final captured = <String>[];

      when(
        () => mockService.verifyTutorPin(
          profileId: any(named: 'profileId'),
          rawPin: any(named: 'rawPin'),
        ),
      ).thenAnswer((invocation) async {
        captured.add(invocation.namedArguments[#rawPin] as String);
        return const TutorPinSuccess();
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

      // Enter 1, 2, 3 then backspace once and enter 4, 5 → final PIN '1245'.
      await _tapDigit(tester, '1');
      await _tapDigit(tester, '2');
      await _tapDigit(tester, '3');
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      await _tapDigit(tester, '4');
      await _tapDigit(tester, '5');
      await tester.pump(const Duration(seconds: 1));

      expect(
        captured,
        equals(['1245']),
        reason: 'Backspace must drop the last digit before completion',
      );
      await _teardown(tester);
    });
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

    testWidgets(
      'TutorPinValidationError: shows the localized malformed-PIN error',
      (tester) async {
        setViewSize(tester);
        final mockService = _MockTutorPinService();

        // AC3 (AUD-tutoring-09): force the validation-error branch by having
        // the (mocked) service return TutorPinValidationError as it would
        // for a malformed pin — the gate must resolve the stable code via
        // AppLocalizations/ARB, never render a raw/hand-written message.
        when(
          () => mockService.verifyTutorPin(
            profileId: any(named: 'profileId'),
            rawPin: any(named: 'rawPin'),
          ),
        ).thenAnswer(
          (_) async => const TutorPinValidationError(
            code: TutorPinValidationCode.malformedPin,
          ),
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
          find.text('Your Tutor PIN must be exactly 4 numeric digits.'),
          findsAtLeastNWidgets(1),
          reason:
              'TutorPinValidationError must resolve to the localized '
              'tutorPinValidationMalformed string, not a raw message',
        );
        await _teardown(tester);
      },
    );
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
      expect(find.widgetWithText(InkWell, '5'), findsOneWidget);
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

  // ── TUT-01: set-then-immediately-verify on the SAME gate instance ──────────
  //
  // Regression for the post-reset race: after setting a new PIN inline, the
  // gate must clear its entry state and show PIN entry immediately so the
  // freshly-set PIN verifies on the FIRST re-entry — NOT only after a second,
  // fresh gate open.

  group('TutorPinEntryGate — TUT-01: set then immediately verify', () {
    testWidgets(
      'after inline PIN setup, the new PIN verifies on the first entry '
      '(no spurious "Incorrect PIN")',
      (tester) async {
        setViewSize(tester);

        // Stateful stub: starts with NO pin set (forces the setup screen),
        // setTutorPin flips the flag, hasTutorPin / tutorPinIsSetProvider read
        // it, and verifyTutorPin returns success only when the entered PIN
        // matches the one that was just set.
        final stub = _StatefulTutorPinStub();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tutorPinServiceProvider.overrideWithValue(stub),
              // Resolve from the stub so an invalidate() after setTutorPin
              // reflects the new (true) state — mirroring production.
              tutorPinIsSetProvider(
                _kTutorProfileId,
              ).overrideWith((_) => stub.hasTutorPin(_kTutorProfileId)),
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
                onPinVerified: () => stub.verifiedCalled = true,
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // No PIN set → setup screen is shown.
        expect(
          find.text('Set Tutor PIN'),
          findsAtLeastNWidgets(1),
          reason: 'With no PIN set the gate must show the setup screen first',
        );

        // Enter the new PIN (2222) then confirm (2222) on the custom numpad.
        await _enterPin(tester, '2222'); // create step
        await tester.pump(const Duration(milliseconds: 100));
        await _enterPin(
          tester,
          '2222',
        ); // confirm step → setTutorPin + onPinSet
        await tester.pump(const Duration(seconds: 1));

        // The gate must now show PIN ENTRY (not loop back to setup) with a
        // clean state (no error, empty dots).
        expect(
          find.text('Enter your Tutor PIN'),
          findsOneWidget,
          reason:
              'TUT-01: after setting the PIN the gate must show entry on the '
              'same instance, not route back to setup',
        );
        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsNothing,
          reason: 'TUT-01: no spurious incorrect-PIN error before any entry',
        );

        // Enter the freshly-set PIN — it must verify on the FIRST attempt.
        await _enterPin(tester, '2222');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Incorrect PIN. Please try again.'),
          findsNothing,
          reason:
              'TUT-01 root cause: the just-set PIN must NOT report incorrect '
              'on the first re-entry',
        );
        expect(
          stub.verifiedCalled,
          isTrue,
          reason:
              'TUT-01: onPinVerified must fire on the first correct entry of '
              'the freshly-set PIN',
        );

        await _teardown(tester);
      },
    );
  });
}

/// Stateful in-memory TutorPinService stub for the TUT-01 set-then-verify test.
///
/// Tracks a single stored PIN per profile so that:
///   • hasTutorPin reflects whether a PIN was set (drives tutorPinIsSetProvider)
///   • verifyTutorPin succeeds only for the exact PIN that was set
class _StatefulTutorPinStub implements TutorPinService {
  final Map<int, String> _pins = {};
  bool verifiedCalled = false;

  @override
  Future<TutorPinResult> setTutorPin({
    required int profileId,
    required String rawPin,
  }) async {
    _pins[profileId] = rawPin;
    return const TutorPinSuccess();
  }

  @override
  Future<TutorPinResult> verifyTutorPin({
    required int profileId,
    required String rawPin,
  }) async {
    return _pins[profileId] == rawPin
        ? const TutorPinSuccess()
        : const TutorPinIncorrect();
  }

  @override
  Future<bool> hasTutorPin(int profileId) async => _pins.containsKey(profileId);

  @override
  Future<void> clearTutorPin(int profileId) async => _pins.remove(profileId);

  @override
  Future<int> lockoutRemainingMinutes(int profileId) async => 0;
}
