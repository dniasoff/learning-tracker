/// OS-01 regression: OverallStatsCard stat labels must be localized.
///
/// Before the fix, the card contained five hard-coded English string literals:
///   "Overall Progress", "Total items", "Completed all stages",
///   "In progress", "Not started"
///
/// In Hebrew locale these labels rendered in English, breaking the Hebrew UI.
/// This test was RED before the l10n keys were added + wired up.
@Tags(['progress', 'i18n', 'os01'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _UseHebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _wrapLocale(Widget child, Locale locale) {
  return ProviderScope(
    overrides: [useHebrewTermsProvider.overrideWith(_UseHebrewTermsOff.new)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

const _stats = OverallCurriculumStats(
  totalItems: 120,
  completedAllStages: 40,
  inProgress: 35,
  notStarted: 45,
);

void main() {
  group(
    'OverallStatsCard — OS-01: stat labels must be localized, not hard-coded',
    () {
      testWidgets(
        'Hebrew locale: "Overall Progress" title renders as the Hebrew l10n string',
        (tester) async {
          await tester.pumpWidget(
            _wrapLocale(
              const OverallStatsCard(stats: _stats),
              const Locale('he'),
            ),
          );
          await tester.pumpAndSettle();

          // After the fix: the Hebrew translation of the Overall Progress header
          // must be visible; the hard-coded English fallback must NOT appear.
          expect(
            find.text('התקדמות כוללת'),
            findsOneWidget,
            reason:
                'OS-01: the card title must use l10n so Hebrew locale shows '
                '"התקדמות כוללת" not the hard-coded English "Overall Progress"',
          );
          expect(
            find.text('Overall Progress'),
            findsNothing,
            reason: 'Hard-coded English must not leak through in Hebrew locale',
          );
        },
      );

      testWidgets(
        'Hebrew locale: "Total items" row label renders as the Hebrew l10n string',
        (tester) async {
          await tester.pumpWidget(
            _wrapLocale(
              const OverallStatsCard(stats: _stats),
              const Locale('he'),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('סה"כ פריטים'),
            findsOneWidget,
            reason:
                'OS-01: Total items must be localized — Hebrew locale must show '
                '"סה"כ פריטים" not the hard-coded English "Total items"',
          );
          expect(find.text('Total items'), findsNothing);
        },
      );

      testWidgets(
        'Hebrew locale: "Completed all stages" row label renders in Hebrew',
        (tester) async {
          await tester.pumpWidget(
            _wrapLocale(
              const OverallStatsCard(stats: _stats),
              const Locale('he'),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('הושלמו כל השלבים'),
            findsOneWidget,
            reason: 'OS-01: "Completed all stages" must be localized in Hebrew',
          );
          expect(find.text('Completed all stages'), findsNothing);
        },
      );

      testWidgets('Hebrew locale: "In progress" row label renders in Hebrew', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapLocale(
            const OverallStatsCard(stats: _stats),
            const Locale('he'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('בתהליך'),
          findsOneWidget,
          reason: 'OS-01: "In progress" must be localized in Hebrew',
        );
        expect(find.text('In progress'), findsNothing);
      });

      testWidgets('Hebrew locale: "Not started" row label renders in Hebrew', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapLocale(
            const OverallStatsCard(stats: _stats),
            const Locale('he'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('טרם הוחל'),
          findsOneWidget,
          reason: 'OS-01: "Not started" must be localized in Hebrew',
        );
        expect(find.text('Not started'), findsNothing);
      });

      testWidgets(
        'English locale: stat labels still render in English after fix',
        (tester) async {
          await tester.pumpWidget(
            _wrapLocale(
              const OverallStatsCard(stats: _stats),
              const Locale('en'),
            ),
          );
          await tester.pumpAndSettle();

          // English locale must continue to display the English strings.
          expect(find.text('Overall Progress'), findsOneWidget);
          expect(find.text('Total items'), findsOneWidget);
          expect(find.text('Completed all stages'), findsOneWidget);
          expect(find.text('In progress'), findsOneWidget);
          expect(find.text('Not started'), findsOneWidget);
        },
      );
    },
  );
}
