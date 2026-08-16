/// Regression test for PP-1 — parent_pin_setup_dialog.dart rapid-tap digit leak.
///
/// ROOT CAUSE: `_onFourDigits()` in `_ParentPinSetupDialogState` transitions
/// from enterNew → confirm WITHOUT raising `_busy = true` first.  A 5th digit
/// tapped while the state-machine is mid-transition (digits reset to '') is
/// appended as digit-1 of the confirm PIN, producing either a spurious
/// "PINs do not match" error or an unintended leading digit in the confirm PIN.
///
/// VERIFY: after entering the 4th digit the dialog must be in a busy /
/// transition-locked state so that any extra taps before the confirm buffer
/// starts are silently dropped.
///
/// The fix is to set `_busy = true` synchronously in the enterNew→confirm
/// branch of `_onFourDigits`, mirroring the verify-mode pattern.
@Tags(['l1', 'profiles', 'pin_flow', 'pp1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockPinService extends Mock implements PinService {}

Widget _buildHarness({
  required PinService pinService,
  String profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY9',
}) {
  return pumpApp(
    retry: (_, __) => null,
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

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  // Find the keypad digit button — use last to avoid title/subtitle matches.
  final finder = find.text(digit).last;
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  group('PP-1 — ParentPinSetupDialog enterNew→confirm busy guard', () {
    testWidgets(
      'PP-1 RED: _onFourDigits sets _busy=true before resetting _digits '
      'so that rapid extra taps are blocked during the transition',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        await tester.pumpWidget(_buildHarness(pinService: ps));
        await tester.pump(const Duration(seconds: 1));

        // Open the dialog.
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 300));

        // Enter 4 digits for the first PIN (enterNew step).
        await _tapDigit(tester, '1');
        await _tapDigit(tester, '2');
        await _tapDigit(tester, '3');
        await _tapDigit(tester, '4');
        // Drain all pending frames so the enterNew→confirm transition is done.
        await tester.pump(const Duration(milliseconds: 100));

        // At this point we must be on the confirm step.
        expect(
          find.text('Confirm New PIN'),
          findsAtLeastNWidgets(1),
          reason:
              'After 4 enterNew digits the dialog must advance to confirm step',
        );

        // Enter exactly 4 correct confirm digits '1234' on a clean buffer.
        // (No spurious leading digit was injected by the rapid-tap race.)
        await _tapDigit(tester, '1');
        await _tapDigit(tester, '2');
        await _tapDigit(tester, '3');
        await _tapDigit(tester, '4');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));

        // setProfilePin must be called with '1234' — not '5123' (the corrupt
        // PIN that would result if the busy guard was missing and a 5th tap
        // slipped into the confirm buffer as its first digit, causing '5123'
        // to be submitted on the 4th confirm tap).
        verify(
          () => ps.setProfilePin('01J6Q2H4A8M7K3P9R5T6V8WXY9', '1234'),
        ).called(1);
        expect(
          find.text('Set Parent PIN'),
          findsNothing,
          reason: 'Dialog must be dismissed after successful matching PINs',
        );
      },
    );

    testWidgets(
      'PP-1 — enterNew→confirm transition does not produce pinsDoNotMatch error '
      'from a rapid extra tap',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        await tester.pumpWidget(_buildHarness(pinService: ps));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 300));

        // Enter 4 digits + an immediate extra tap.
        for (final d in '1234'.split('')) {
          await _tapDigit(tester, d);
        }
        await _tapDigit(tester, '9'); // extra rapid tap

        await tester.pump(const Duration(milliseconds: 100));

        // After the transition, confirm must show no error yet
        // (the extra '9' must NOT have been accepted as digit-1 of confirm).
        expect(
          find.textContaining('do not match'),
          findsNothing,
          reason:
              'No mismatch error must appear immediately after enterNew→confirm '
              'transition — the 5th tap must be swallowed by the busy guard',
        );
      },
    );
  });
}
