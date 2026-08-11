// L1 widget tests for TutorPinSetupScreen (lib/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart)
//
// Covers:
//   • Rendering — initial state (enterPin step) with correct l10n labels
//   • Rendering — AppBar title, heading, body text, icon present
//   • Rendering — "Set up later" button shown only when onSkip is provided
//   • Behaviour — entering first 4-digit PIN advances to confirmPin step
//   • Behaviour — entering mismatching confirm PIN shows mismatch error and
//                 resets to step 1
//   • Behaviour — entering matching confirm PIN calls the service and, on
//                 TutorPinSuccess, calls onPinSet
//   • Behaviour — service returning TutorPinValidationError shows the error
//                 message and resets to step 1
//   • Behaviour — service returning TutorPinIncorrect shows generic save error
//   • Behaviour — service returning TutorPinLockedOut shows generic save error
//   • Behaviour — tapping "Set up later" calls onSkip

@Tags(['l1', 'tutoring', 'pin_setup'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Stub TutorPinService
// ---------------------------------------------------------------------------

/// A [TutorPinService] stub that returns a pre-configured result.
///
/// Uses a function so tests can configure different return values.
class _StubTutorPinService implements TutorPinService {
  _StubTutorPinService({required this.setResult});

  final Future<TutorPinResult> Function(String profileId, String rawPin) setResult;

  @override
  Future<TutorPinResult> setTutorPin({
    required String profileId,
    required String rawPin,
  }) => setResult(profileId, rawPin);

  @override
  Future<TutorPinResult> verifyTutorPin({
    required String profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();

  @override
  Future<bool> hasTutorPin(String profileId) async => false;

  @override
  Future<void> clearTutorPin(String profileId) async {}

  @override
  Future<int> lockoutRemainingMinutes(String profileId) async => 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [TutorPinSetupScreen] in the canonical pump harness.
///
/// [stubService] — the [TutorPinService] to inject. Defaults to a service that
/// always returns [TutorPinSuccess].
///
/// [onPinSet], [onSkip] — callbacks forwarded to the screen.
///
/// [locale] — defaults to English; pass `const Locale('he')` for RTL.
Widget _buildHarness({
  required TutorPinService stubService,
  required VoidCallback onPinSet,
  VoidCallback? onSkip,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [tutorPinServiceProvider.overrideWithValue(stubService)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TutorPinSetupScreen(
        profileId: '42',
        onPinSet: onPinSet,
        onSkip: onSkip,
      ),
    ),
  );
}

/// Enters a 4-digit PIN by tapping the always-visible custom numpad (TUT-07).
///
/// The setup screen uses a custom on-screen numpad (NOT TextFields / the device
/// soft-keyboard), matching the TutorPinEntryGate — so digits are entered by
/// tapping the rendered digit keys.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'PIN must be 4 digits');
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.widgetWithText(InkWell, pin[i]));
    await tester.pump();
  }
  // Give the screen time to advance steps / call setTutorPin.
  await tester.pump(const Duration(milliseconds: 100));
}

/// Teardown that disposes all widgets cleanly (avoids stream/timer leaks).
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Suppress size warnings — some screens need more vertical space.
  setUp(() {});

  group('TutorPinSetupScreen — initial render (enterPin step)', () {
    testWidgets('renders a Scaffold', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });

    testWidgets('shows l10n AppBar title "Set Tutor PIN"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      expect(find.text('Set Tutor PIN'), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });

    testWidgets('shows "Create your Tutor PIN" heading on step 1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      expect(find.text('Create your Tutor PIN'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('shows create body text on step 1', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Tutor PIN protects access'),
        findsOneWidget,
        reason: 'tutorPinSetupCreateBody must be visible on step 1',
      );
      await _teardown(tester);
    });

    testWidgets('shows lock_person_rounded icon', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('hides "Set up later" button when onSkip is null', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
          onSkip: null,
        ),
      );
      await tester.pump();

      expect(find.text('Set up later'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('shows "Set up later" button when onSkip is provided', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
          onSkip: () {},
        ),
      );
      await tester.pump();

      expect(find.text('Set up later'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('shows the custom numpad with "Enter New PIN" label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      // The numpad step label renders as Text — "Enter New PIN"
      expect(find.text('Enter New PIN'), findsOneWidget);
      await _teardown(tester);
    });

    // TUT-07: setup uses an always-visible custom numpad (no soft-keyboard
    // TextFields), matching the TutorPinEntryGate.
    testWidgets('renders an always-visible numpad (0-9) — no TextFields', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      // No soft-keyboard TextFields (TUT-07 — the old PinEntryWidget was dead).
      expect(find.byType(TextField), findsNothing);
      // All ten digit keys are tappable on the custom numpad.
      for (var d = 0; d <= 9; d++) {
        expect(
          find.widgetWithText(InkWell, '$d'),
          findsOneWidget,
          reason: 'Numpad must render a tappable key for digit $d',
        );
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('TutorPinSetupScreen — step transition (enterPin → confirmPin)', () {
    testWidgets('entering first PIN advances to confirm step', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      // Enter the first 4-digit PIN.
      await _enterPin(tester, '1234');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Heading changes to "Confirm your Tutor PIN".
      expect(find.text('Confirm your Tutor PIN'), findsOneWidget);
      // Create heading is gone.
      expect(find.text('Create your Tutor PIN'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('confirm step shows "Confirm PIN" label', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Confirm PIN'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('confirm step shows confirm body text', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Re-enter the same 4-digit PIN to confirm.'),
        findsOneWidget,
      );
      await _teardown(tester);
    });
  });

  group('TutorPinSetupScreen — PIN mismatch', () {
    testWidgets(
      'entering non-matching confirm PIN shows mismatch error and resets to step 1',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (_, __) async => const TutorPinSuccess(),
            ),
            onPinSet: () {},
          ),
        );
        await tester.pump();

        // Step 1: enter first PIN.
        await _enterPin(tester, '1234');
        await tester.pump(const Duration(milliseconds: 100));

        // Step 2: enter a DIFFERENT confirm PIN.
        await _enterPin(tester, '9999');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        // Mismatch error must appear.
        expect(
          find.text('PINs do not match. Please try again.'),
          findsOneWidget,
          reason: 'l10n.tutorPinSetupMismatch must be shown on PIN mismatch',
        );
        // Screen resets to step 1.
        expect(find.text('Create your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  group('TutorPinSetupScreen — matching PIN (TutorPinSuccess)', () {
    testWidgets(
      'entering matching confirm PIN calls setTutorPin and then onPinSet',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var onPinSetCalled = false;
        String? serviceProfileId;
        String? servicePin;

        await tester.pumpWidget(
          _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (profileId, rawPin) async {
                serviceProfileId = profileId;
                servicePin = rawPin;
                return const TutorPinSuccess();
              },
            ),
            onPinSet: () => onPinSetCalled = true,
          ),
        );
        await tester.pump();

        // Step 1.
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(milliseconds: 100));

        // Step 2 — same PIN.
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        expect(serviceProfileId, '42', reason: 'correct profileId passed');
        expect(servicePin, '5678', reason: 'correct PIN passed');
        expect(onPinSetCalled, isTrue, reason: 'onPinSet called on success');
        await _teardown(tester);
      },
    );
  });

  group('TutorPinSetupScreen — service error paths', () {
    testWidgets(
      'TutorPinValidationError shows error message and resets to step 1',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // AC3 (AUD-tutoring-09): force the validation-error branch by having
        // the (stub) service return TutorPinValidationError as it would for
        // a malformed pin — the screen must resolve the stable code via
        // AppLocalizations/ARB, never render a raw/hand-written message.
        await tester.pumpWidget(
          _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (_, __) async => const TutorPinValidationError(
                code: TutorPinValidationCode.malformedPin,
              ),
            ),
            onPinSet: () {},
          ),
        );
        await tester.pump();

        // Enter matching PINs so the service is called.
        await _enterPin(tester, '1111');
        await tester.pump(const Duration(milliseconds: 100));
        await _enterPin(tester, '1111');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Your Tutor PIN must be exactly 4 numeric digits.'),
          findsOneWidget,
          reason:
              'TutorPinValidationError must resolve to the localized '
              'tutorPinValidationMalformed string, not a raw message',
        );
        // Resets to step 1.
        expect(find.text('Create your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );

    testWidgets(
      'TutorPinIncorrect shows generic save error and resets to step 1',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (_, __) async => const TutorPinIncorrect(),
            ),
            onPinSet: () {},
          ),
        );
        await tester.pump();

        await _enterPin(tester, '2222');
        await tester.pump(const Duration(milliseconds: 100));
        await _enterPin(tester, '2222');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Unable to save PIN. Please try again.'),
          findsOneWidget,
          reason:
              'l10n.tutorPinSetupSaveError must appear for TutorPinIncorrect',
        );
        expect(find.text('Create your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );

    testWidgets(
      'TutorPinLockedOut shows generic save error and resets to step 1',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (_, __) async =>
                  const TutorPinLockedOut(remainingMinutes: 5),
            ),
            onPinSet: () {},
          ),
        );
        await tester.pump();

        await _enterPin(tester, '3333');
        await tester.pump(const Duration(milliseconds: 100));
        await _enterPin(tester, '3333');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Unable to save PIN. Please try again.'),
          findsOneWidget,
          reason:
              'l10n.tutorPinSetupSaveError must appear for TutorPinLockedOut',
        );
        expect(find.text('Create your Tutor PIN'), findsOneWidget);
        await _teardown(tester);
      },
    );
  });

  group('TutorPinSetupScreen — AUD-tutoring-15: accessibility', () {
    testWidgets('backspace key exposes a non-empty semantic label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
        ),
      );
      await tester.pump();

      // The backspace numpad key surfaces its `semanticLabel:` on the Icon
      // ('Delete' — l10n.pinBackspace, en). find.bySemanticsLabel walks the
      // semantics tree directly, so it does not depend on which ancestor
      // Widget happens to own the merged SemanticsNode.
      expect(
        find.bySemanticsLabel('Delete'),
        findsOneWidget,
        reason:
            'AUD-tutoring-15: the backspace numpad key must expose a '
            'non-empty semantic label for screen readers',
      );

      handle.dispose();
      await _teardown(tester);
    });

    testWidgets('numpad renders without RenderFlex overflow at textScale 2.0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _buildHarness(
            stubService: _StubTutorPinService(
              setResult: (_, __) async => const TutorPinSuccess(),
            ),
            onPinSet: () {},
          ),
        ),
      );
      await tester.pump();

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

  group('TutorPinSetupScreen — AUD-tutoring-04: setTutorPin throws', () {
    testWidgets('shows the generic save error and resets to step 1 instead of '
        'silently stalling on the confirm step', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var onPinSetCalled = false;

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) => throw Exception('keystore unavailable'),
          ),
          onPinSet: () => onPinSetCalled = true,
        ),
      );
      await tester.pump();

      // Enter matching PINs so the service is called and throws.
      await _enterPin(tester, '4321');
      await tester.pump(const Duration(milliseconds: 100));
      await _enterPin(tester, '4321');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Saving spinner must clear once the throw is handled',
      );
      expect(
        find.text('Unable to save PIN. Please try again.'),
        findsOneWidget,
        reason:
            'AUD-tutoring-04: an uncaught exception from setTutorPin must '
            'surface tutorPinSetupSaveError, not a silent stall',
      );
      // Resets to step 1 so the user can retry.
      expect(find.text('Create your Tutor PIN'), findsOneWidget);
      expect(
        onPinSetCalled,
        isFalse,
        reason: 'onPinSet must not fire on a thrown exception',
      );
      await _teardown(tester);
    });
  });

  group('TutorPinSetupScreen — skip button', () {
    testWidgets('tapping "Set up later" calls onSkip', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var skipCalled = false;

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
          onSkip: () => skipCalled = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Set up later'));
      await tester.pump();

      expect(skipCalled, isTrue, reason: 'onSkip must be called on tap');
      await _teardown(tester);
    });
  });

  // ── AUD-t-tutoring-01 — Hebrew (RTL) variant ─────────────────────────────
  //
  // Mirrors tutor_pin_entry_gate_l1_test.dart's Hebrew group (TQ-3): key
  // screens in the tutor-PIN flow must carry a Locale('he') smoke test so
  // RTL/overflow regressions are not invisible to an LTR-only suite.
  group('TutorPinSetupScreen — AUD-t-tutoring-01: Hebrew (RTL) variant', () {
    testWidgets('he locale: renders enterPin step without overflow or crash', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildHarness(
          stubService: _StubTutorPinService(
            setResult: (_, __) async => const TutorPinSuccess(),
          ),
          onPinSet: () {},
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No RenderFlex overflow exceptions — assert key structural widgets.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);

      await _teardown(tester);
    });
  });
}
