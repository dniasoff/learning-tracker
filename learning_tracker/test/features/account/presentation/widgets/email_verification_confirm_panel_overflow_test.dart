// Overflow guard — EmailVerificationConfirmPanel (P1 dialog).
//
// Root cause guarded here: the panel was a Column with no scroll escape valve,
// so under a constrained-height host (or large text) the illustration + title +
// long body + button stack overflowed vertically; and the Send-Again / Cancel
// action Row overflowed horizontally on narrow viewports (the formerly-skipped
// H1 RTL case). The fix wraps the body in a SingleChildScrollView and lets the
// button labels flex/ellipsize.
//
// We pump the real [EmailVerificationConfirmPanel] across the device/text-scale
// matrix with a long body string and assert no RenderFlex overflow, in both
// LTR and RTL.

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_confirm_panel.dart';

import '../../../../helpers/overflow_harness.dart';

const _kLongBody =
    'We just sent a verification link to your email address. Open it on this '
    'device and tap the link to confirm your account. The link expires in 24 '
    'hours; if you do not see it, check your spam folder or send it again.';

Widget _panel() => const Center(
  child: EmailVerificationConfirmPanel(
    title: 'Confirm Your Email',
    bodyText: _kLongBody,
    email: 'someone.with.a.long.address@example.com',
    onSendAgain: _noop,
    onCancel: _noopVoid,
    onVerified: _noop,
  ),
);

Future<void> _noop() async {}
void _noopVoid() {}

void main() {
  testWidgets(
    'EmailVerificationConfirmPanel (long body) does not overflow across the '
    'device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(tester, _panel);
    },
  );

  testWidgets(
    'EmailVerificationConfirmPanel does not overflow in Hebrew (RTL) — the '
    'former H1 action-Row overflow',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        _panel,
        locale: const Locale('he'),
      );
    },
  );
}
