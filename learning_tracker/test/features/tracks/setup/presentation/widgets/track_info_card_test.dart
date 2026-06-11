/// Regression test for TS-9:
/// TrackInfoCard._elapsedRemainingLabel must NOT prepend the elapsed label
/// text to the value — that label is already displayed as the row's label,
/// so the value should be just "N days" (not "Elapsed N days").
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_info_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// We test the pure private logic by triggering it through the widget.
// The simplest approach: expose the label via a public helper function.
// Since [TrackInfoCard._elapsedRemainingLabel] is private, we test it
// by checking what the built widget actually puts into the "Elapsed" row.

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('TS-9 — TrackInfoCard elapsed row value', () {
    testWidgets('elapsed value is "N days", not "Elapsed N days"', (
      tester,
    ) async {
      // We test elapsedRemainingLabel which is public after the fix.
      // Before the fix it prepended l10n.trackInfoElapsed to the value.
      // After the fix the value is just "$N $days".
      //
      // The simplest regression: call the public function with known inputs
      // and assert the output does not start with the elapsed label text.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      final l10n = tester.element(find.byType(SizedBox)).l10n;

      final label = elapsedRemainingLabel(
        l10n: l10n,
        elapsedDays: 5,
        remainingDays: null,
      );

      // Bug: "Elapsed 5 days" — the word "Elapsed" appeared twice in the row.
      // Fix: value should be "5 days" (label column already says "Elapsed").
      expect(
        label.startsWith(l10n.trackInfoElapsed),
        isFalse,
        reason: 'value must not repeat the elapsed label text (TS-9)',
      );
      expect(label, contains('5'));
    });

    testWidgets(
      'when remaining days present, neither part starts with the elapsed label',
      (tester) async {
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(SizedBox)).l10n;

        final label = elapsedRemainingLabel(
          l10n: l10n,
          elapsedDays: 10,
          remainingDays: 20,
        );

        // The full value must NOT start with the elapsed label text.
        expect(label.startsWith(l10n.trackInfoElapsed), isFalse);
        // Both day counts should appear in the value.
        expect(label, contains('10'));
        expect(label, contains('20'));
      },
    );
  });
}

extension _L10nFromElement on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
