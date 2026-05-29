// L1 widget tests for ParentPinKeypadDialog
// (showParentPinVerificationDialog + showParentPinChangeDialog)
//
// Covers:
//   • Verification dialog — renders title/subtitle
//   • Digit entry — each tap fills a dot (3 filled dots → dot row length 3)
//   • Backspace — removes last digit
//   • Max-length — 5th digit tap is ignored (stays at 4)
//   • Correct PIN → verifyProfilePin returns true → dialog pops with true
//   • Wrong PIN → verifyProfilePin returns false → error message, stays open
//   • Lockout → PinLockoutException → lockout panel shown, keypad hidden
//   • Cancel keypad button → dialog pops with false
//   • Close (×) button → dialog pops with false
//   • Change-PIN flow: verify current → enter new → confirm new → success snackbar
//   • Change-PIN: wrong current PIN shows error + stays on verifyCurrent step
//   • Change-PIN: confirm mismatch shows error + resets to enterNew step
//   • Analytics: logParentModeEntered fires exactly once on success
//   • he (RTL) locale: renders without overflow/crash
@Tags(['l1', 'profiles', 'parent_pin_keypad'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockPinService extends Mock implements PinService {}

class _MockAnalytics extends Mock implements AnalyticsService {}

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kProfileId = 42;

// ── Harness ───────────────────────────────────────────────────────────────────

/// Pumps a [Scaffold] with a single [ElevatedButton] that opens the verification
/// dialog when tapped. Returns the dialog result via [onResult].
Widget _verificationHarness({
  required PinService pinService,
  AnalyticsService? analytics,
  required void Function(bool) onResult,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            key: const Key('open_verify'),
            onPressed: () async {
              final result = await showParentPinVerificationDialog(
                ctx,
                profileId: _kProfileId,
                pinService: pinService,
                analytics: analytics,
              );
              onResult(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// Pumps a [Scaffold] with a button that opens the change-PIN dialog.
Widget _changeHarness({
  required PinService pinService,
  required void Function(bool) onResult,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            key: const Key('open_change'),
            onPressed: () async {
              final result = await showParentPinChangeDialog(
                ctx,
                profileId: _kProfileId,
                pinService: pinService,
              );
              onResult(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// Opens the verification dialog by tapping the trigger button.
Future<void> _openVerificationDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_verify')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the change-PIN dialog by tapping the trigger button.
Future<void> _openChangeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_change')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Taps a digit key on the visible keypad.
Future<void> _tapDigit(WidgetTester tester, String digit) async {
  // Digit buttons are Text widgets with single digit inside _KeypadChip.
  final digitFinder = find.text(digit);
  expect(digitFinder, findsAtLeastNWidgets(1));
  await tester.tap(digitFinder.first);
  await tester.pump();
}

/// Taps the backspace key.
Future<void> _tapBackspace(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.backspace_outlined));
  await tester.pump();
}

/// Enters a 4-digit PIN via keypad taps.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'pin must be exactly 4 digits');
  for (final ch in pin.split('')) {
    await _tapDigit(tester, ch);
  }
}

/// Disposes all widgets cleanly to avoid timer/stream leaks.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Counts how many of the 4 PIN dots are filled (navy colour).
///
/// Strategy: the filled dot is a Container with BoxDecoration(shape: circle,
/// color: brandInk = 0xFF1B2330, border: ...) and NO child.  The empty dot
/// has color 0xFFE8EBF0 and has a child (the inner 4×4 centre dot).
///
/// We detect filled by counting Containers that have the specific navy color
/// AND circular BoxDecoration shape.
int _filledDotCount(WidgetTester tester) {
  const filledColor = Color(0xFF1B2330); // AppTheme.brandInk
  var filled = 0;
  for (final widget in tester.allWidgets) {
    if (widget is Container) {
      final deco = widget.decoration;
      if (deco is BoxDecoration &&
          deco.shape == BoxShape.circle &&
          deco.color == filledColor) {
        filled++;
      }
    }
  }
  return filled;
}

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ── Verification dialog renders ─────────────────────────────────────────────

  group('ParentPinKeypadDialog — verification: renders', () {
    testWidgets('shows "Enter Parent PIN" title', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();
      bool? result;

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (r) => result = r),
      );
      await _openVerificationDialog(tester);

      expect(find.text('Enter Parent PIN'), findsAtLeastNWidgets(1));
      expect(result, isNull); // dialog still open

      await _teardown(tester);
    });

    testWidgets('shows subtitle text', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      expect(
        find.text('Enter your 4-digit PIN to access parent settings.'),
        findsAtLeastNWidgets(1),
      );

      await _teardown(tester);
    });

    testWidgets('shows 4-dot row in initial empty state', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      // All 4 dots should be empty (no filled dots).
      expect(_filledDotCount(tester), 0);

      await _teardown(tester);
    });
  });

  // ── Digit entry ─────────────────────────────────────────────────────────────

  group('ParentPinKeypadDialog — digit entry fills dots', () {
    testWidgets('tapping 1 digit fills 1 dot', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      await _tapDigit(tester, '3');

      expect(_filledDotCount(tester), 1);

      await _teardown(tester);
    });

    testWidgets('tapping 3 digits fills 3 dots', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      await _tapDigit(tester, '1');
      await _tapDigit(tester, '2');
      await _tapDigit(tester, '3');

      expect(_filledDotCount(tester), 3);

      await _teardown(tester);
    });
  });

  // ── Backspace ───────────────────────────────────────────────────────────────

  group('ParentPinKeypadDialog — backspace', () {
    testWidgets('backspace removes last digit', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      await _tapDigit(tester, '7');
      await _tapDigit(tester, '8');
      expect(_filledDotCount(tester), 2);

      await _tapBackspace(tester);
      expect(_filledDotCount(tester), 1);

      await _teardown(tester);
    });

    testWidgets('backspace on empty does nothing', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      // Tap backspace on empty — should not crash
      await _tapBackspace(tester);
      expect(_filledDotCount(tester), 0);

      await _teardown(tester);
    });
  });

  // ── Max-length enforcement ──────────────────────────────────────────────────

  group('ParentPinKeypadDialog — max length', () {
    testWidgets('5th digit tap is ignored; stays at 4 dots', (tester) async {
      setViewSize(tester);
      // Return a non-completing future so the submission does not fire synchronously
      // before we can tap the 5th digit. We need to capture the in-flight state.
      // Since auto-submit fires when 4th digit is tapped and verifyProfilePin
      // is called, we make it return a non-resolving future.
      final completer = Completer<bool>();
      final svc = _MockPinService();
      when(
        () => svc.verifyProfilePin(any<int>(), any<String>()),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      // Tap 4 digits — auto-submit fires but is in-flight (completer not done)
      await _tapDigit(tester, '1');
      await _tapDigit(tester, '2');
      await _tapDigit(tester, '3');
      await _tapDigit(tester, '4');
      await tester.pump();

      // At 4 filled dots (busy=true, so keypad disabled)
      expect(_filledDotCount(tester), 4);

      // Tap a 5th digit — should be ignored (busy)
      await _tapDigit(tester, '5');
      expect(_filledDotCount(tester), 4);

      // Complete so cleanup can proceed
      completer.complete(false);
      await tester.pump(const Duration(seconds: 1));

      await _teardown(tester);
    });
  });

  // ── Correct PIN → success ───────────────────────────────────────────────────

  group('ParentPinKeypadDialog — correct PIN → dialog returns true', () {
    testWidgets(
      'correct PIN calls verifyProfilePin with profileId+digits and result is true',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        bool? dialogResult;
        int? capturedProfileId;
        String? capturedPin;

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((inv) async {
          capturedProfileId = inv.positionalArguments[0] as int;
          capturedPin = inv.positionalArguments[1] as String;
          return true;
        });

        await tester.pumpWidget(
          _verificationHarness(
            pinService: svc,
            onResult: (r) => dialogResult = r,
          ),
        );
        await _openVerificationDialog(tester);

        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        expect(capturedProfileId, _kProfileId);
        expect(capturedPin, '1234');
        expect(dialogResult, isTrue);

        await _teardown(tester);
      },
    );

    testWidgets(
      'analytics.logParentModeEntered fires exactly once on correct PIN',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        final analytics = _MockAnalytics();
        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => true);
        when(
          () => analytics.logParentModeEntered(profileId: any(named: 'profileId')),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          _verificationHarness(
            pinService: svc,
            analytics: analytics,
            onResult: (_) {},
          ),
        );
        await _openVerificationDialog(tester);

        await _enterPin(tester, '5678');
        await tester.pump(const Duration(seconds: 1));

        verify(
          () => analytics.logParentModeEntered(profileId: _kProfileId),
        ).called(1);

        await _teardown(tester);
      },
    );
  });

  // ── Wrong PIN → error + stays open ─────────────────────────────────────────

  group('ParentPinKeypadDialog — wrong PIN → error shown', () {
    testWidgets(
      'wrong PIN shows "Incorrect PIN" error and dialog stays open',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        bool? dialogResult;

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _verificationHarness(
            pinService: svc,
            onResult: (r) => dialogResult = r,
          ),
        );
        await _openVerificationDialog(tester);

        await _enterPin(tester, '9999');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Incorrect PIN'),
          findsAtLeastNWidgets(1),
          reason: 'incorrectPin l10n text must appear after wrong PIN',
        );
        // Dialog is still open → result not delivered yet
        expect(dialogResult, isNull);
        // Title still visible
        expect(find.text('Enter Parent PIN'), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );

    testWidgets('wrong PIN clears the digits (dot row resets to 0)', (
      tester,
    ) async {
      setViewSize(tester);
      final svc = _MockPinService();

      when(
        () => svc.verifyProfilePin(any<int>(), any<String>()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _verificationHarness(pinService: svc, onResult: (_) {}),
      );
      await _openVerificationDialog(tester);

      await _enterPin(tester, '1111');
      await tester.pump(const Duration(seconds: 1));

      // After wrong PIN, digits are cleared → 0 filled dots
      expect(_filledDotCount(tester), 0);

      await _teardown(tester);
    });

    testWidgets(
      'entering a new digit after wrong PIN clears the error message',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _verificationHarness(pinService: svc, onResult: (_) {}),
        );
        await _openVerificationDialog(tester);

        await _enterPin(tester, '2222');
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Incorrect PIN'), findsAtLeastNWidgets(1));

        // Typing a new digit clears the error
        await _tapDigit(tester, '5');
        expect(find.text('Incorrect PIN'), findsNothing);

        await _teardown(tester);
      },
    );
  });

  // ── Lockout ─────────────────────────────────────────────────────────────────

  group('ParentPinKeypadDialog — lockout panel', () {
    testWidgets(
      'PinLockoutException → lockout panel shown with minutes; keypad hidden',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        bool? dialogResult;

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenThrow(const PinLockoutException(7));

        await tester.pumpWidget(
          _verificationHarness(
            pinService: svc,
            onResult: (r) => dialogResult = r,
          ),
        );
        await _openVerificationDialog(tester);

        await _enterPin(tester, '3333');
        await tester.pump(const Duration(seconds: 1));

        // Lockout panel text
        expect(
          find.text('Too many failed attempts'),
          findsAtLeastNWidgets(1),
          reason: '_LockoutPanel must show lockout message',
        );
        expect(
          find.textContaining('7'),
          findsAtLeastNWidgets(1),
          reason: 'Lockout message must include remaining minutes (7)',
        );
        // Keypad (backspace icon) should NOT be visible once locked out
        expect(find.byIcon(Icons.backspace_outlined), findsNothing);
        // Dialog still open
        expect(dialogResult, isNull);

        await _teardown(tester);
      },
    );
  });

  // ── Cancel / close ──────────────────────────────────────────────────────────

  group('ParentPinKeypadDialog — cancel / close → dialog returns false', () {
    testWidgets('Cancel button on keypad pops dialog with false', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();
      bool? dialogResult;

      await tester.pumpWidget(
        _verificationHarness(
          pinService: svc,
          onResult: (r) => dialogResult = r,
        ),
      );
      await _openVerificationDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(seconds: 1));

      expect(dialogResult, isFalse);

      await _teardown(tester);
    });

    testWidgets('Close (×) button pops dialog with false', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();
      bool? dialogResult;

      await tester.pumpWidget(
        _verificationHarness(
          pinService: svc,
          onResult: (r) => dialogResult = r,
        ),
      );
      await _openVerificationDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(seconds: 1));

      expect(dialogResult, isFalse);

      await _teardown(tester);
    });
  });

  // ── Change-PIN flow ─────────────────────────────────────────────────────────

  group('ParentPinKeypadDialog — change PIN flow', () {
    testWidgets(
      'happy path: verify current → enter new → confirm new → snackbar + returns true',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        bool? dialogResult;

        // verifyProfilePin succeeds on 1st call
        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => true);
        // setProfilePin succeeds
        when(
          () => svc.setProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          _changeHarness(pinService: svc, onResult: (r) => dialogResult = r),
        );
        await _openChangeDialog(tester);

        // Step 1: verifyCurrent
        expect(find.text('Enter Current PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // Step 2: enterNew
        expect(find.text('Enter New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(seconds: 1));

        // Step 3: confirmNew
        expect(find.text('Confirm New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(seconds: 1));

        // Snackbar
        expect(
          find.text('PIN changed successfully'),
          findsAtLeastNWidgets(1),
          reason: 'pinChangedSuccessfully snackbar must appear on success',
        );

        // Dialog returns true
        expect(dialogResult, isTrue);

        verify(() => svc.setProfilePin(_kProfileId, '5678')).called(1);

        await _teardown(tester);
      },
    );

    testWidgets(
      'wrong current PIN shows error and stays on verifyCurrent step',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();
        bool? dialogResult;

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _changeHarness(pinService: svc, onResult: (r) => dialogResult = r),
        );
        await _openChangeDialog(tester);

        expect(find.text('Enter Current PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '0000');
        await tester.pump(const Duration(seconds: 1));

        // Error message
        expect(find.text('Incorrect PIN'), findsAtLeastNWidgets(1));
        // Still on verifyCurrent (not on enterNew step)
        expect(find.text('Enter Current PIN'), findsAtLeastNWidgets(1));
        expect(find.text('Enter New PIN'), findsNothing);
        expect(dialogResult, isNull);

        await _teardown(tester);
      },
    );

    testWidgets(
      'confirm mismatch shows "PINs do not match" and resets to enterNew',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          _changeHarness(pinService: svc, onResult: (_) {}),
        );
        await _openChangeDialog(tester);

        // Step 1: verify current
        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // Step 2: enter new PIN
        expect(find.text('Enter New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '1111');
        await tester.pump(const Duration(seconds: 1));

        // Step 3: confirm with DIFFERENT PIN
        expect(find.text('Confirm New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '2222');
        await tester.pump(const Duration(seconds: 1));

        // Error: PINs do not match
        expect(
          find.text('PINs do not match'),
          findsAtLeastNWidgets(1),
          reason: 'pinsDoNotMatch l10n text must appear on mismatch',
        );
        // Resets to enterNew step
        expect(find.text('Enter New PIN'), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );

    testWidgets(
      'lockout during change-PIN verify step shows lockout panel',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();

        when(
          () => svc.verifyProfilePin(any<int>(), any<String>()),
        ).thenThrow(const PinLockoutException(3));

        await tester.pumpWidget(
          _changeHarness(pinService: svc, onResult: (_) {}),
        );
        await _openChangeDialog(tester);

        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Too many failed attempts'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining('3'),
          findsAtLeastNWidgets(1),
        );

        await _teardown(tester);
      },
    );
  });

  // ── PinKeypadDialogFrame smoke ──────────────────────────────────────────────

  group('PinKeypadDialogFrame — direct render', () {
    testWidgets('renders title, subtitle, dots, keypad', (tester) async {
      setViewSize(tester);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PinKeypadDialogFrame(
                title: 'Test Title',
                subtitle: 'Test subtitle',
                digits: '',
                errorMessage: null,
                lockedOut: false,
                lockoutMinutes: 0,
                busy: false,
                onClose: () {},
                onDigit: (_) {},
                onBackspace: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Title'), findsAtLeastNWidgets(1));
      expect(find.text('Test subtitle'), findsAtLeastNWidgets(1));
      // Close button
      expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));
      // Backspace icon in keypad
      expect(find.byIcon(Icons.backspace_outlined), findsAtLeastNWidgets(1));
      // Cancel text button
      expect(find.text('Cancel'), findsAtLeastNWidgets(1));
      // All 10 digit buttons (0-9) must be present
      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(find.text(d), findsAtLeastNWidgets(1));
      }

      await _teardown(tester);
    });

    testWidgets('lockedOut=true shows lockout panel; no backspace', (
      tester,
    ) async {
      setViewSize(tester);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PinKeypadDialogFrame(
                title: 'Test Title',
                subtitle: 'Test subtitle',
                digits: '',
                errorMessage: null,
                lockedOut: true,
                lockoutMinutes: 12,
                busy: false,
                onClose: () {},
                onDigit: (_) {},
                onBackspace: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.lock_clock), findsAtLeastNWidgets(1));
      expect(
        find.text('Too many failed attempts'),
        findsAtLeastNWidgets(1),
      );
      expect(find.textContaining('12'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.backspace_outlined), findsNothing);

      await _teardown(tester);
    });

    testWidgets('errorMessage is shown in error colour text widget', (
      tester,
    ) async {
      setViewSize(tester);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PinKeypadDialogFrame(
                title: 'Test Title',
                subtitle: 'Sub',
                digits: '',
                errorMessage: 'Custom error msg',
                lockedOut: false,
                lockoutMinutes: 0,
                busy: false,
                onClose: () {},
                onDigit: (_) {},
                onBackspace: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Custom error msg'), findsAtLeastNWidgets(1));

      await _teardown(tester);
    });

    testWidgets('busy=true disables digit and backspace taps', (tester) async {
      setViewSize(tester);
      var digitCalled = false;
      var backspaceCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PinKeypadDialogFrame(
                title: 'Title',
                subtitle: 'Sub',
                digits: '12',
                errorMessage: null,
                lockedOut: false,
                lockoutMinutes: 0,
                busy: true,
                onClose: () {},
                onDigit: (_) => digitCalled = true,
                onBackspace: () => backspaceCalled = true,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap digit '5' and backspace while busy — callbacks must NOT fire
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(digitCalled, isFalse, reason: 'digit tap must be no-op when busy');
      expect(
        backspaceCalled,
        isFalse,
        reason: 'backspace tap must be no-op when busy',
      );

      await _teardown(tester);
    });
  });

  // ── Hebrew (RTL) locale smoke ───────────────────────────────────────────────

  group('ParentPinKeypadDialog — Hebrew (RTL) locale smoke', () {
    testWidgets(
      'he locale: verification dialog renders without overflow or crash',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();

        await tester.pumpWidget(
          _verificationHarness(
            pinService: svc,
            onResult: (_) {},
            locale: const Locale('he'),
          ),
        );
        await _openVerificationDialog(tester);

        // Should render without crash
        expect(find.byType(Dialog), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );

    testWidgets(
      'he locale: change-PIN dialog renders without overflow or crash',
      (tester) async {
        setViewSize(tester);
        final svc = _MockPinService();

        await tester.pumpWidget(
          _changeHarness(
            pinService: svc,
            onResult: (_) {},
            locale: const Locale('he'),
          ),
        );
        await _openChangeDialog(tester);

        expect(find.byType(Dialog), findsAtLeastNWidgets(1));

        await _teardown(tester);
      },
    );
  });
}
