/// Regression for device-audit run-8 (R3/input, device 5560): the Set/Confirm
/// parent-PIN keypad silently DROPPED taps at normal typing speed, surfacing as
/// a false "PINs do not match".
///
/// ROOT CAUSE: each keypad key registered on `InkWell.onTap`, which only fires
/// when the pointer lifts within `kTouchSlop` (~18 logical px) of where it
/// landed. A fast finger tap on a real device routinely drifts past that, so the
/// tap recognizer rejected the press as a drag and the digit was dropped. The
/// user's first (Set) entry lost a digit, so the second (Confirm) entry could
/// never match. `tester.tap` injects a zero-movement tap, which is why the
/// pre-existing keypad tests never reproduced it.
///
/// FIX: `_KeypadChip` registers the key on `onTapDown` — drift-immune, like a
/// hardware keypad — so every press counts regardless of finger drift.
///
/// These tests drive the keypad with real gestures that DRIFT past the tap slop
/// and assert every digit registers.
@Tags(['l1', 'profiles', 'pin_flow', 'reassurance'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockPinService extends Mock implements PinService {}

Widget _setupHarness({required PinService pinService, int profileId = 99}) {
  return pumpApp(
    overrides: [pinServiceProvider.overrideWithValue(pinService)],
    child: Consumer(
      builder: (ctx, ref, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                showParentPinSetupDialog(ctx, ref, profileId: profileId),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// Taps [digit] on the keypad with a vertical finger DRIFT of [driftPx] between
/// touch-down and lift — simulating a fast real-device tap. With the old
/// `onTap` wiring a drift past `kTouchSlop` (~18) was silently dropped.
Future<void> _driftTapDigit(
  WidgetTester tester,
  String digit, {
  double driftPx = 26,
}) async {
  // `.last` avoids the title/subtitle text; keypad keys are the trailing match.
  final center = tester.getCenter(find.text(digit).last);
  final gesture = await tester.startGesture(center);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveBy(Offset(0, driftPx));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  // ~0.3s between keypresses — "normal typing speed" from the finding.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    registerFallbackValue('');
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('f-pin-keypad-taps — drifting keypad taps all register', () {
    testWidgets(
      'Set then Confirm PIN via drifting taps saves the full PIN (no false '
      'mismatch)',
      (tester) async {
        setViewSize(tester);

        final ps = _MockPinService();
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        await tester.pumpWidget(_setupHarness(pinService: ps));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 300));

        // Set step — every digit drifts past the tap slop.
        for (final d in '1234'.split('')) {
          await _driftTapDigit(tester, d);
        }
        await tester.pump(const Duration(milliseconds: 100));

        // Must have advanced to Confirm — proves all 4 Set digits registered.
        expect(
          find.text('Confirm New PIN'),
          findsAtLeastNWidgets(1),
          reason:
              'A dropped Set-step tap would leave the keypad on "Set Parent '
              'PIN" (never reaching 4 digits)',
        );

        // Confirm step — same PIN, also with drift.
        for (final d in '1234'.split('')) {
          await _driftTapDigit(tester, d);
        }
        await tester.pump(const Duration(milliseconds: 300));

        // The full, correct PIN must have been saved — not a short/shifted one.
        verify(() => ps.setProfilePin(99, '1234')).called(1);
        expect(
          find.textContaining('do not match'),
          findsNothing,
          reason: 'No false "PINs do not match" when no tap was dropped',
        );
      },
    );

    testWidgets('every drifting digit fills a dot (none dropped)', (
      tester,
    ) async {
      setViewSize(tester);

      var registered = 0;
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: Center(
              child: PinKeypadDialogFrame(
                title: 'T',
                subtitle: 'S',
                digits: '',
                errorMessage: null,
                lockedOut: false,
                lockoutMinutes: 0,
                busy: false,
                onClose: () {},
                onDigit: (_) => registered++,
                onBackspace: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Rapid succession (per finding) AND with drift past the tap slop.
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
        await _driftTapDigit(tester, d, driftPx: 30);
      }

      expect(
        registered,
        10,
        reason: 'all 10 drifting keypad presses must register onDigit',
      );
    });

    testWidgets('busy=true still swallows a drifting tap', (tester) async {
      setViewSize(tester);

      var registered = 0;
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: Center(
              child: PinKeypadDialogFrame(
                title: 'T',
                subtitle: 'S',
                digits: '12',
                errorMessage: null,
                lockedOut: false,
                lockoutMinutes: 0,
                busy: true,
                onClose: () {},
                onDigit: (_) => registered++,
                onBackspace: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await _driftTapDigit(tester, '5', driftPx: 30);

      expect(
        registered,
        0,
        reason: 'busy keypad must remain fully disabled even for a tap-down',
      );
    });
  });
}
