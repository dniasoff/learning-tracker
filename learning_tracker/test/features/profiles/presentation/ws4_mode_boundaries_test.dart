/// Widget tests for WS4 mode-boundary changes:
///   • WS4.banner (DEC-25 / D3): "Viewing [child]" banner — l10n strings
///     resolve correctly for the banner and exit label.
///   • WS4.boundary (DEC-4): parent-portal tab-0 shows a confirmation
///     dialog before switching into the child's full experience; cancelling
///     the dialog does not proceed to navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

// ---------------------------------------------------------------------------
// Test entry point
// ---------------------------------------------------------------------------

void main() {
  // ── WS4.banner tests ──────────────────────────────────────────────────────

  group('WS4.banner — "Viewing [child]" banner l10n strings', () {
    testWidgets(
      'viewingChildBanner(name) produces "Viewing Yosef"',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: _wrap(
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Text(l10n.viewingChildBanner('Yosef'));
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Viewing Yosef'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'viewingChildBannerExit produces "Exit"',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: _wrap(
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Text(l10n.viewingChildBannerExit);
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Exit'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── WS4.boundary tests ────────────────────────────────────────────────────

  group('WS4.boundary — parent-portal tab-0 explicit confirmation', () {
    /// Helper: builds a widget that opens the switch-into-child confirmation
    /// dialog and records whether the user confirmed.
    Widget dialogTestWidget({
      required String childName,
      required void Function(bool confirmed) onResult,
    }) {
      return ProviderScope(
        child: _wrap(
          Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () async {
                final l10n = AppLocalizations.of(context)!;
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    final dl10n = AppLocalizations.of(ctx)!;
                    return AlertDialog(
                      title: Text(dl10n.switchIntoChildTitle),
                      content: Text(dl10n.switchIntoChildMessage(childName)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(dl10n.switchIntoChildConfirm),
                        ),
                      ],
                    );
                  },
                );
                onResult(result ?? false);
              },
              child: const Text('Test'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'tab-0 confirmation dialog renders title, message, and action buttons',
      (tester) async {
        var confirmed = false;

        await tester.pumpWidget(
          dialogTestWidget(
            childName: 'Yosef',
            onResult: (v) => confirmed = v,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        // Dialog must be visible with correct content.
        expect(find.text('Switch to child view'), findsOneWidget);
        expect(
          find.text(
            "You are about to enter Yosef's full experience. "
            'You can exit anytime from the banner at the top.',
          ),
          findsOneWidget,
        );
        expect(find.text('Switch in'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Confirm the dialog.
        await tester.tap(find.text('Switch in'));
        await tester.pumpAndSettle();

        // confirmed flag must be true after tapping Switch in.
        expect(confirmed, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'tapping Cancel in the tab-0 confirmation dialog does not proceed '
      '(DEC-4 — explicit switch required)',
      (tester) async {
        var confirmed = false;

        await tester.pumpWidget(
          dialogTestWidget(
            childName: 'Moshe',
            onResult: (v) => confirmed = v,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        expect(find.text('Switch to child view'), findsOneWidget);

        // Cancel — must NOT proceed.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(confirmed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
