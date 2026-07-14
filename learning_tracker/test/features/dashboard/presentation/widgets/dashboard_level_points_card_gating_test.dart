// Regression test for BUG-7 — DashboardLevelPointsCard must not show a points
// label to adult profiles (product rule: adults have no points).
//
// Child mode renders "<n> pts" in the card's top-right; adult mode suppresses
// it entirely. The rest of the card (task bubbles, lifetime progress) is
// mode-agnostic and stays visible in both modes.
@Tags(['dashboard', 'gamification'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_level_points_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _wrap({required ProfileMode userMode, required int totalPoints}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DashboardLevelPointsCard(
            userMode: userMode,
            level: 3,
            totalPoints: totalPoints,
            overdueCount: 1,
            todayCount: 2,
            reviewCount: 0,
            doneDisplay: '12%',
            lifetimeSectionsDetail: '12 of 100 sections',
            cumulativeLifetime: 0.12,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('BUG-7: child mode shows the points label', (tester) async {
    await tester.pumpWidget(
      _wrap(userMode: ProfileMode.child, totalPoints: 42),
    );
    await tester.pumpAndSettle();

    // l10n pointsAbbrev => "42 pts".
    expect(find.text('42 pts'), findsOneWidget);
  });

  testWidgets('BUG-7: adult mode hides the points label entirely', (
    tester,
  ) async {
    // Adults always have 0 points; the label must not render at all (not even
    // "0 pts").
    await tester.pumpWidget(_wrap(userMode: ProfileMode.adult, totalPoints: 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('pts'), findsNothing);
    // The mode-agnostic content is still present.
    expect(find.textContaining('section'), findsOneWidget);
  });
}
