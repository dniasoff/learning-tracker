// Regression tests for:
//   AN-9  — Form validation errors stale until next submit
//          Root cause: no autovalidateMode set → errors linger after user
//          types valid input. Fix: autovalidateMode = onUserInteraction.
//   AN-11 — No "Forgot password?" affordance on sign-in.
//          Root cause: SignInForm had no onForgotPassword callback or link.
//          Fix: added optional onForgotPassword param + TextButton.
//   AN-12 — Password field shows masked-dot placeholder "••••••••".
//          Root cause: signInPasswordHint l10n key was '••••••••'.
//          Fix: changed to a plain text hint.

@Tags(['account', 'sign_in', 'an9', 'an11', 'an12'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_form.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildSignInForm({
  VoidCallback? onForgotPassword,
  String? Function(String?)? validatePassword,
}) {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          return SignInForm(
            formKey: formKey,
            emailController: emailCtrl,
            passwordController: passwordCtrl,
            isLoading: false,
            obscurePassword: true,
            keepSignedIn: true,
            registrySubtitle: null,
            l10n: l10n,
            onEmailChanged: (_) {},
            onPasswordToggle: () {},
            onKeepSignedInChanged: (_) {},
            onSubmit: () {},
            validateEmail: (v) =>
                (v == null || v.isEmpty) ? 'Email required' : null,
            validatePassword:
                validatePassword ??
                (v) => (v == null || v.isEmpty) ? 'Password required' : null,
            onForgotPassword: onForgotPassword,
          );
        },
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SignInForm — AN-9, AN-11, AN-12 regression', () {
    // ── AN-12 ──────────────────────────────────────────────────────────────────
    testWidgets(
      'AN-12: password field hint is NOT masked dots (plain text hint)',
      (tester) async {
        await tester.pumpWidget(_buildSignInForm());
        await tester.pump();

        // The hint text rendered in the password field must NOT equal the old
        // masked-dot placeholder '••••••••'. We verify via the underlying
        // TextField widgets (TextFormField wraps TextField).
        final textFields = tester.widgetList<TextField>(find.byType(TextField));
        var foundDotHint = false;
        for (final field in textFields) {
          final hintText = field.decoration?.hintText;
          if (hintText == '••••••••') {
            foundDotHint = true;
          }
        }
        expect(
          foundDotHint,
          isFalse,
          reason: 'AN-12: no password field should have masked-dot hint text',
        );
      },
    );

    // ── AN-11 ──────────────────────────────────────────────────────────────────
    testWidgets(
      'AN-11: "Forgot password?" link is absent when onForgotPassword is null',
      (tester) async {
        await tester.pumpWidget(_buildSignInForm(onForgotPassword: null));
        await tester.pump();

        expect(
          find.textContaining('Forgot'),
          findsNothing,
          reason: 'AN-11: no forgot-password link when callback is null',
        );
      },
    );

    testWidgets(
      // AN-11: FAILS before fix (no TextButton with Forgot text); PASSES after.
      'AN-11: "Forgot password?" link appears and fires callback when provided',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _buildSignInForm(onForgotPassword: () => tapped = true),
        );
        await tester.pump();

        expect(
          find.textContaining('Forgot'),
          findsOneWidget,
          reason: 'AN-11: forgot-password link must appear when callback set',
        );

        await tester.tap(find.textContaining('Forgot'));
        await tester.pump();

        expect(tapped, isTrue, reason: 'AN-11: tapping link fires callback');
      },
    );

    // ── AN-9 ───────────────────────────────────────────────────────────────────
    testWidgets(
      // AN-9: FAILS before fix (no autovalidateMode) — validation error
      // appears only on form submit, not when user types valid input.
      // PASSES after fix (autovalidateMode: onUserInteraction).
      'AN-9: validation error clears immediately when user types valid input',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        final emailCtrl = TextEditingController();
        final passwordCtrl = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  final l10n = AppLocalizations.of(ctx)!;
                  return Column(
                    children: [
                      Expanded(
                        child: SignInForm(
                          formKey: formKey,
                          emailController: emailCtrl,
                          passwordController: passwordCtrl,
                          isLoading: false,
                          obscurePassword: false, // reveal for typing
                          keepSignedIn: false,
                          registrySubtitle: null,
                          l10n: l10n,
                          onEmailChanged: (_) {},
                          onPasswordToggle: () {},
                          onKeepSignedInChanged: (_) {},
                          onSubmit: () {},
                          validateEmail: (v) => (v == null || v.isEmpty)
                              ? 'Email required'
                              : null,
                          validatePassword: (v) => (v == null || v.isEmpty)
                              ? 'Password required'
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Trigger validation by calling validate() (simulates a submit).
        formKey.currentState!.validate();
        await tester.pump();

        // Error text should now be visible.
        expect(
          find.text('Password required'),
          findsOneWidget,
          reason: 'Error must appear after submit-validation',
        );

        // AN-9 FIX: typing a valid password should clear the error immediately
        // (autovalidateMode: onUserInteraction). Before the fix, the error would
        // persist until the next form.validate() call.
        await tester.enterText(
          // Find the second TextFormField (the password field)
          find.byType(TextFormField).last,
          'mysecretpassword',
        );
        await tester.pump();

        expect(
          find.text('Password required'),
          findsNothing,
          reason:
              'AN-9: error must clear immediately when user types valid input',
        );
      },
    );
  });
}
