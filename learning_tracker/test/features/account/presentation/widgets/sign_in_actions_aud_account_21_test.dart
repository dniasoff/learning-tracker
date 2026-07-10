// Regression test for AUD-account-21:
//   "Give SignInActions' TapGestureRecognizer a disposal owner instead of
//   rebuilding it every build()"
//
// Root cause: SignInActions was a StatelessWidget, so every build() (e.g.
// each time isLoading flips) allocated a brand-new TapGestureRecognizer for
// the "Register" span that nothing ever disposed. InlineSpan does not manage
// the lifetime of its recognizer (see Flutter's own TextSpan.recognizer
// docs), so the framework never calls .dispose() on it either — it is
// created and immediately orphaned on every rebuild.
//
// Fix: SignInActions became a StatefulWidget; the TapGestureRecognizer is
// created once in State.initState() and disposed in State.dispose().

@Tags(['account', 'sign_in', 'aud-account-21'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildSignInActions({
  required bool isLoading,
  bool isOnline = true,
  VoidCallback? onRegister,
}) {
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
          return SignInActions(
            isLoading: isLoading,
            isOnline: isOnline,
            l10n: l10n,
            onSignIn: () {},
            onGoogleSignIn: () {},
            onRegister: onRegister ?? () {},
          );
        },
      ),
    ),
  );
}

/// Depth-first search for the first [TextSpan] carrying a non-null
/// [TapGestureRecognizer] — that is the "Register Here" span.
TapGestureRecognizer? _findRecognizer(InlineSpan span) {
  if (span is TextSpan) {
    if (span.recognizer is TapGestureRecognizer) {
      return span.recognizer as TapGestureRecognizer;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _findRecognizer(child);
      if (found != null) return found;
    }
  }
  return null;
}

/// SignInActions renders several widgets that internally use RichText (e.g.
/// [Text]), so we must scan every RichText in the tree for the one carrying
/// the Register-span recognizer rather than assuming find.byType matches one.
TapGestureRecognizer? _extractRegisterRecognizer(WidgetTester tester) {
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    final found = _findRecognizer(rt.text);
    if (found != null) return found;
  }
  return null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SignInActions — AUD-account-21 regression', () {
    testWidgets(
      // FAILS before fix: a StatelessWidget.build() allocates a fresh
      // TapGestureRecognizer every time it runs, so the recognizer captured
      // after the isLoading flip is a different instance (and the first one
      // leaked, orphaned with nothing to dispose it).
      // PASSES after fix: the recognizer is created once in State.initState()
      // and reused across rebuilds.
      'Register TapGestureRecognizer is created once and reused across '
      'rebuilds, not reallocated on every build()',
      (tester) async {
        await tester.pumpWidget(_buildSignInActions(isLoading: false));
        await tester.pump();

        final recognizerBefore = _extractRegisterRecognizer(tester);
        expect(
          recognizerBefore,
          isNotNull,
          reason: 'Register span must carry a TapGestureRecognizer',
        );

        // Trigger a rebuild the same way the real SignInScreen does: the
        // isLoading flag flips while SignInActions occupies the same
        // Element (no key change, no remount) — this is exactly the
        // rebuild path AUD-account-21 describes.
        await tester.pumpWidget(_buildSignInActions(isLoading: true));
        await tester.pump();

        final recognizerAfter = _extractRegisterRecognizer(tester);
        expect(
          recognizerAfter,
          isNotNull,
          reason: 'Register span must still carry a TapGestureRecognizer',
        );

        expect(
          identical(recognizerBefore, recognizerAfter),
          isTrue,
          reason:
              'AUD-account-21: the TapGestureRecognizer must be created '
              'once and disposed via State.dispose(), not reallocated on '
              'every SignInActions.build()',
        );
      },
    );

    testWidgets(
      'tapping "Register Here" still invokes onRegister when not loading '
      '(behavior preserved after the StatefulWidget refactor)',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _buildSignInActions(
            isLoading: false,
            onRegister: () => tapped = true,
          ),
        );
        await tester.pump();

        // "Register Here" lives inside a TextSpan nested in a RichText
        // alongside sibling spans, so a plain widget-center tap can land
        // outside the recognizer's glyphs. tapOnText finds a hit-testable
        // offset within the matched substring itself.
        await tester.tapOnText(find.textRange.ofSubstring('Register'));
        await tester.pump();

        expect(
          tapped,
          isTrue,
          reason: 'Tapping the Register span must still fire onRegister',
        );
      },
    );

    testWidgets('the Register tap is a no-op while isLoading is true (behavior '
        'preserved after the StatefulWidget refactor)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildSignInActions(isLoading: true, onRegister: () => tapped = true),
      );
      await tester.pump();

      await tester.tapOnText(find.textRange.ofSubstring('Register'));
      await tester.pump();

      expect(
        tapped,
        isFalse,
        reason: 'Tapping the Register span while isLoading must be a no-op',
      );
    });

    testWidgets('widget disposes cleanly when removed from the tree', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSignInActions(isLoading: false));
      await tester.pump();

      // Replace the whole tree so SignInActions' State.dispose() runs. This
      // must not throw — if the recognizer field were never disposed there
      // would be no crash either, but this guards against a broken dispose()
      // override (e.g. missing super.dispose() or a double-dispose bug).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
