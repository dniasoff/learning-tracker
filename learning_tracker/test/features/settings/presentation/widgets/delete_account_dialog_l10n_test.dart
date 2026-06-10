// Regression tests for SET-08 / loop-iter10:
// delete_account_dialog.dart previously leaked hardcoded English strings:
//   - Body text: "This action is permanent and cannot be undone..."
//   - Reauth note: "You will be asked to re-enter your password..."
//   - Reauth note (Google): "You will be asked to sign in with Google..."
//   - Confirm button label: "Delete Account" (hardcoded, not using l10n key)
//
// These tests pump the dialog in Hebrew locale (he) and verify:
//   SET-08-A. No hardcoded English body text appears
//   SET-08-B. No hardcoded English reauth password note appears
//   SET-08-C. No hardcoded English reauth Google note appears
//   SET-08-D. Confirm button shows Hebrew text, not English "Delete Account"
//   SET-08-E. Body text is translated (Hebrew warning copy appears)
//   SET-08-F. Reauth password note is translated (Hebrew copy appears)
//   SET-08-G. Reauth Google note is translated (Hebrew copy appears)

@Tags(['l1', 'settings', 'l10n', 'set08'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Widget builder ─────────────────────────────────────────────────────────────

Widget _deleteDialogApp({
  Locale locale = const Locale('he'),
  bool needsReauth = false,
  String? reauthProvider,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open_delete_dialog'),
            onPressed: () => showDeleteAccountDialog(
              context: context,
              needsReauth: needsReauth,
              reauthProvider: reauthProvider,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_delete_dialog')));
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════════
  // SET-08-A/E: Body warning text — no English, yes Hebrew
  // ════════════════════════════════════════════════════════════════════════════

  group('DeleteAccountDialog body text — Hebrew l10n (SET-08-A/E)', () {
    testWidgets('SET-08-A: no hardcoded English body text in Hebrew locale', (
      tester,
    ) async {
      await _pump(tester, _deleteDialogApp());
      await _openDialog(tester);

      expect(find.textContaining('This action is permanent'), findsNothing);

      await _teardown(tester);
    });

    testWidgets('SET-08-E: Hebrew warning body text appears', (tester) async {
      await _pump(tester, _deleteDialogApp());
      await _openDialog(tester);

      // The Hebrew translation must appear somewhere in the dialog body.
      expect(find.textContaining('לצמיתות'), findsAtLeast(1));

      await _teardown(tester);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SET-08-B/F: Password reauth note — no English, yes Hebrew
  // ════════════════════════════════════════════════════════════════════════════

  group(
    'DeleteAccountDialog password reauth note — Hebrew l10n (SET-08-B/F)',
    () {
      testWidgets(
        'SET-08-B: no hardcoded English reauth-password note in Hebrew locale',
        (tester) async {
          await _pump(tester, _deleteDialogApp(needsReauth: true));
          await _openDialog(tester);

          expect(
            find.textContaining('You will be asked to re-enter'),
            findsNothing,
          );

          await _teardown(tester);
        },
      );

      testWidgets('SET-08-F: Hebrew reauth-password note appears', (
        tester,
      ) async {
        await _pump(tester, _deleteDialogApp(needsReauth: true));
        await _openDialog(tester);

        // Hebrew translation for the password reauth note must appear.
        expect(find.textContaining('סיסמה'), findsAtLeast(1));

        await _teardown(tester);
      });
    },
  );

  // ════════════════════════════════════════════════════════════════════════════
  // SET-08-C/G: Google reauth note — no English, yes Hebrew
  // ════════════════════════════════════════════════════════════════════════════

  group('DeleteAccountDialog Google reauth note — Hebrew l10n (SET-08-C/G)', () {
    testWidgets(
      'SET-08-C: no hardcoded English reauth-Google note in Hebrew locale',
      (tester) async {
        await _pump(
          tester,
          _deleteDialogApp(needsReauth: true, reauthProvider: 'Google'),
        );
        await _openDialog(tester);

        expect(
          find.textContaining('You will be asked to sign in with Google'),
          findsNothing,
        );

        await _teardown(tester);
      },
    );

    testWidgets('SET-08-G: Hebrew reauth-Google note contains provider name', (
      tester,
    ) async {
      await _pump(
        tester,
        _deleteDialogApp(needsReauth: true, reauthProvider: 'Google'),
      );
      await _openDialog(tester);

      // The Hebrew note contains the provider name (substituted in the
      // placeholder — "Google" stays in Latin script as it is a proper noun).
      expect(find.textContaining('Google'), findsAtLeast(1));

      await _teardown(tester);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SET-08-D: Confirm button — no hardcoded English
  // ════════════════════════════════════════════════════════════════════════════

  group('DeleteAccountDialog confirm button — Hebrew l10n (SET-08-D)', () {
    testWidgets(
      'SET-08-D: confirm button does not show hardcoded English "Delete Account"',
      (tester) async {
        await _pump(tester, _deleteDialogApp());
        await _openDialog(tester);

        // The button text must NOT be the hardcoded English string.
        // It should use the l10n key (deleteAccountDialogTitle).
        expect(find.text('Delete Account'), findsNothing);

        await _teardown(tester);
      },
    );
  });
}
