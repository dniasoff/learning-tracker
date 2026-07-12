/// AUD-progress-11 regression: MonthlyActivitySliverCalendar's user-facing
/// strings must be localized, not hand-rolled English literals.
///
/// Before the fix, the widget contained three hard-coded English string
/// sites:
///   - `Text('No activity data')` (empty-state fallback)
///   - `'$monthLabel  —  ${rollup.activeDays} active day(s)'` (sticky header)
///   - `'${rollup.totalCompletions} completion(s)'` (compact summary card)
///
/// In Hebrew locale these all rendered in English, breaking the Hebrew UI
/// (AX-2). This test was RED before the l10n keys were added and wired up.
@Tags(['progress', 'i18n', 'aud-progress-11'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/monthly_activity_sliver_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _wrapLocale(Widget child, Locale locale) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: SizedBox(height: 600, child: child)),
  );
}

MonthlyActivityRollup _rollup({
  required String yearMonth,
  required int activeDays,
  required int totalCompletions,
}) {
  return MonthlyActivityRollup(
    profileId: 1,
    yearMonth: yearMonth,
    activeDays: activeDays,
    totalCompletions: totalCompletions,
    totalChazaros: 0,
    firstActivityDate: null,
    lastActivityDate: null,
    activeDaysList: '1 2 3',
  );
}

void main() {
  group(
    'MonthlyActivitySliverCalendar — AUD-progress-11: strings must be localized',
    () {
      testWidgets(
        'Hebrew locale: empty-state fallback renders the Hebrew l10n string, '
        'not the hard-coded English literal',
        (tester) async {
          await tester.pumpWidget(
            _wrapLocale(
              const MonthlyActivitySliverCalendar(rollups: []),
              const Locale('he'),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);

          expect(
            find.text('אין נתוני פעילות'),
            findsOneWidget,
            reason:
                'AUD-progress-11: the empty-state fallback must use l10n so '
                'Hebrew locale shows the Hebrew translation, not the '
                'hard-coded English "No activity data"',
          );
          expect(
            find.text('No activity data'),
            findsNothing,
            reason: 'Hard-coded English must not leak through in Hebrew locale',
          );
        },
      );

      testWidgets(
        'Hebrew locale: month header active-days phrase renders in Hebrew, '
        'not the hand-rolled English ternary',
        (tester) async {
          final rollup = _rollup(
            yearMonth: '2026-05',
            activeDays: 3,
            totalCompletions: 5,
          );

          await tester.pumpWidget(
            _wrapLocale(
              MonthlyActivitySliverCalendar(rollups: [rollup], locale: 'he'),
              const Locale('he'),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);

          // Hebrew ICU plural (other-category, 3 active days).
          expect(
            find.textContaining('ימים פעילים'),
            findsOneWidget,
            reason:
                'AUD-progress-11: the sticky header active-days phrase must '
                'use l10n/ICU plural so Hebrew locale shows the Hebrew '
                'plural form',
          );
          // The hand-rolled English ternary output must not appear anywhere.
          expect(find.textContaining('active day'), findsNothing);
          expect(find.textContaining('active days'), findsNothing);
        },
      );

      testWidgets(
        'Hebrew locale: compact-card completions count renders in Hebrew, '
        'not the hand-rolled English ternary',
        (tester) async {
          final rollup = _rollup(
            yearMonth: '2026-05',
            activeDays: 1,
            totalCompletions: 5,
          );

          await tester.pumpWidget(
            _wrapLocale(
              MonthlyActivitySliverCalendar(rollups: [rollup], locale: 'he'),
              const Locale('he'),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);

          // Hebrew ICU plural (other-category, 5 completions).
          expect(
            find.textContaining('השלמות'),
            findsOneWidget,
            reason:
                'AUD-progress-11: the compact-card completions phrase must '
                'use l10n/ICU plural so Hebrew locale shows the Hebrew '
                'plural form',
          );
          // The hand-rolled English ternary output must not appear anywhere.
          expect(find.textContaining('completion'), findsNothing);
          expect(find.textContaining('completions'), findsNothing);
        },
      );

      testWidgets(
        'English locale: strings still render in English after the fix',
        (tester) async {
          final rollup = _rollup(
            yearMonth: '2026-05',
            activeDays: 1,
            totalCompletions: 1,
          );

          await tester.pumpWidget(
            _wrapLocale(
              MonthlyActivitySliverCalendar(rollups: [rollup], locale: 'en'),
              const Locale('en'),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.textContaining('1 active day'), findsOneWidget);
          expect(find.textContaining('1 completion'), findsOneWidget);
        },
      );
    },
  );
}
