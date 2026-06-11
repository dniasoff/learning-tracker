/// Regression test for PP-12 — PIN change flow reuses the verify-gate subtitle.
///
/// ROOT CAUSE: `_ParentPinChangeDialog._subtitle()` returns
/// `l10n.enterParentPinSubtitle` ("Enter your 4-digit PIN to access parent
/// settings.") for the `verifyCurrent` step of the Change-PIN flow. The user
/// is confirming identity to CHANGE the PIN — not to access parent settings —
/// so the subtitle is misleading.
///
/// FIX: Add a dedicated `enterCurrentPinSubtitle` string
/// ("Enter your current 4-digit PIN to change it.") and return it for the
/// `verifyCurrent` step in `_subtitle()`.
///
/// RED test: opens the change-PIN dialog and asserts that the OLD subtitle
/// "to access parent settings" is NOT present on the `verifyCurrent` step.
/// This fails before the fix because the buggy code renders that string.
///
/// GREEN test: asserts the CORRECT subtitle is present after the fix.
@Tags(['unit', 'profiles', 'pin_flow', 'pp12'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinService extends Mock implements PinService {}

Widget _buildHarness({required PinService pinService, int profileId = 42}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showParentPinChangeDialog(
              ctx,
              profileId: profileId,
              pinService: pinService,
            ),
            child: const Text('change'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PP-12 — PIN change flow subtitle is change-specific on verifyCurrent step', () {
    testWidgets(
      'PP-12: verifyCurrent step must NOT show "to access parent settings" subtitle',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        // verifyProfilePin is not called until digits are entered; don't stub.
        await tester.pumpWidget(_buildHarness(pinService: ps));
        await tester.pump(const Duration(seconds: 1));

        // Open the change-PIN dialog.
        await tester.tap(find.text('change'));
        await tester.pump(const Duration(milliseconds: 300));

        // The dialog must be showing the "Enter Current PIN" title.
        expect(
          find.text('Enter Current PIN'),
          findsAtLeastNWidgets(1),
          reason: 'Change-PIN dialog must open on the verifyCurrent step',
        );

        // BUG: Before the fix, the subtitle "to access parent settings" would
        // appear here, misleading the user into thinking they are accessing
        // parent settings rather than changing their PIN.
        expect(
          find.textContaining('access parent settings'),
          findsNothing,
          reason:
              'PP-12 fix: the verifyCurrent step of the Change-PIN flow must NOT '
              'show "to access parent settings" — that subtitle belongs to the '
              'verify gate, not the change flow.',
        );

        // FIX: The correct subtitle should indicate the user is changing their PIN.
        expect(
          find.textContaining('to change it'),
          findsAtLeastNWidgets(1),
          reason:
              'PP-12 fix: the verifyCurrent step must show a change-flow subtitle '
              '("Enter your current 4-digit PIN to change it.").',
        );
      },
    );
  });
}
