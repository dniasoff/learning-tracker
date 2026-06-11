// Widget test — DeadlineGoalCard pace line (goal_cards.dart)
//
// Finding 3: the "(≈{totalItems} items)" parenthetical must NEVER render
// "≈0 items". When the scope count has not yet resolved to a positive number
// the parenthetical is omitted (the no-total pace line is shown instead);
// once the count is positive the full line with the item total renders.

@Tags(['tracks', 'goal_step', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _buildCard({
  required int totalScopeItems,
  required int studyDaysInWindow,
  bool scopeIsLoading = false,
  Locale locale = const Locale('en'),
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
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return SingleChildScrollView(
            child: DeadlineGoalCard(
              isActive: true,
              deadline: DateTime(2030, 1, 1),
              dateLabel: 'Jan 1, 2030',
              useHebrew: false,
              studyDaysInWindow: studyDaysInWindow,
              itemsPerStudyDay: 1,
              totalScopeItems: totalScopeItems,
              scopeIsLoading: scopeIsLoading,
              unitLabel: 'Daf',
              onTapDate: () {},
              l10n: l10n,
            ),
          );
        },
      ),
    ),
  );
}

/// Concatenates every rendered Text string in the tree.
String _allText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if (t.data != null) buffer.write('${t.data}\n');
  }
  return buffer.toString();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('zero scope items → no "≈0 items" parenthetical', (tester) async {
    await tester.pumpWidget(
      _buildCard(totalScopeItems: 0, studyDaysInWindow: 5),
    );
    await tester.pump();

    final text = _allText(tester);
    // The defect: the parenthetical rendered "≈0 items". After the guard it
    // must never appear — neither the "≈0" nor any "0 items".
    expect(
      text.contains('≈0'),
      isFalse,
      reason: 'must never display "≈0 items"',
    );
    expect(text.contains('0 items'), isFalse);
    // The per-study-day estimate is still shown (the no-total variant).
    expect(text.contains('per study day'), isTrue);
  });

  testWidgets('positive scope items → full line with item total shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCard(totalScopeItems: 120, studyDaysInWindow: 5),
    );
    await tester.pump();

    final text = _allText(tester);
    // Positive count → the "(≈120 items)" parenthetical is present.
    expect(text.contains('120 items'), isTrue);
    expect(text.contains('≈0'), isFalse);
  });
}
