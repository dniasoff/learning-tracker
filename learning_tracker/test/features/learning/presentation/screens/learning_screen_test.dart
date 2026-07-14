// AUD-t-learning-02: this file used to also cover LearningScreen directly
// ("renders without error", "shows key UI elements"), but both of those
// tests were a strict, weaker subset of learning_screen_l1_test.dart's
// empty-state coverage (same setup, same-or-fewer assertions), and their
// dashboardActiveCurriculaProvider / dashboardUserModeProvider overrides
// were dead — LearningScreen.build() reads neither (it watches
// dashboardActiveCurriculaStreamProvider, and derives isChildMode from
// selectedProfileProvider). Both were deleted per TQ-7, not parked.
//
// The one non-duplicate test below — AppErrorView renders the generic
// message and never leaks an InternalException's raw string — doesn't
// exercise LearningScreen at all (it pumps AppErrorView directly in a bare
// Scaffold), so this file is kept (rather than deleted outright) only
// because AG-5's test-mirroring ratchet (tool/check_test_mirroring.dart)
// requires an exact-path test/.../learning_screen_test.dart mirror to exist
// for lib/.../learning_screen.dart regardless of what it covers;
// learning_screen_l1_test.dart is the actual LearningScreen coverage.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('LearningScreen', () {
    // V2-R5 C3 regression: AppErrorView.build must never render raw exception
    // strings. This test directly verifies AppErrorView renders "Something went
    // wrong" (not the raw internal message) for an InternalException.
    testWidgets('AppErrorView shows generic message for InternalException (not raw '
        'exception string)', (tester) async {
      const rawMsg = 'internal error detail that must not appear in UI';
      // Directly render AppErrorView — this is what _DailyTasksSection's
      // error branch now emits after the V2-R5 C3 fix.
      //
      // AUD-core-sync-27: uses [SeedManagerException] (a real InternalException
      // leaf genuinely thrown in production — lib/core/database/seed_manager.dart)
      // instead of the removed MergeException, which was never thrown anywhere
      // in lib/ (dead scaffolding from the W7.2 backlog item; the merge-failure
      // telemetry it was meant to carry is fired via inline AppLogger/analytics
      // calls instead — W7.5/W7.6). Any InternalException leaf exercises the
      // SAME category-generic-message behavior under test here.
      // Not `const` — SeedManagerException's constructor is non-const
      // (unlike the removed MergeException's), so this widget subtree
      // cannot be a const expression.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppErrorView(
              error: SeedManagerException(rawMsg),
              onRetry: null,
            ),
          ),
        ),
      );
      await tester.pump();

      // AppErrorView must be present and show generic "Something went wrong"
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      // Raw exception message must NOT appear anywhere in the UI
      expect(find.text(rawMsg), findsNothing);
      expect(find.textContaining(rawMsg), findsNothing);
    });
  });
}
