/// AUD-content_browsing-01 regression: [ItemReviewBreakdown]'s fallback label
/// for an unresolved stage name was a hard-coded English literal
/// ('Stage $id'), leaking English into the Hebrew UI whenever a stage name
/// could not be resolved. This test was RED before the fallback was routed
/// through AppLocalizations.
@Tags(['content_browsing', 'i18n'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/item_review_breakdown.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  Widget buildHost({required Locale locale}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: ItemReviewBreakdown(
          // Stage 7 has no entry in stageNames, so the widget must fall back
          // to the localized "Stage {id}" label rather than a bare literal.
          stageBreakdown: {7: 3},
          stageNames: {},
        ),
      ),
    );
  }

  group('ItemReviewBreakdown — AUD-content_browsing-01: stage fallback', () {
    testWidgets(
      'Hebrew locale: unresolved stage renders "שלב 7" not "Stage 7"',
      (tester) async {
        await tester.pumpWidget(buildHost(locale: const Locale('he')));
        await tester.pumpAndSettle();

        expect(
          find.text('שלב 7: 3'),
          findsOneWidget,
          reason:
              'AUD-content_browsing-01: unresolved-stage fallback must use '
              'l10n so Hebrew locale shows "שלב 7" not the hard-coded '
              'English "Stage 7"',
        );
        expect(find.textContaining('Stage 7'), findsNothing);
      },
    );

    testWidgets('English locale: unresolved stage still renders "Stage 7"', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Stage 7: 3'), findsOneWidget);
    });
  });
}
