/// Regression tests for the Lifetime Marking screen (W5-D / Task #18).
///
/// Asserts the W5-D copy contract: the screen now renders both the existing
/// title and the new tier-policy subtitle sourced from the
/// [AppLocalizations.lifetimeMarkingSubtitle] l10n key (added in W2). The
/// subtitle explains the lifetimeOnly source so users understand the tier
/// credit — Counted toward Lifetime Knowledge, not toward siyumim/streak/points.
///
/// See `docs/planning/progress-ia-redesign.md` §9.
@Tags(['settings', 'lifetime_marking'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'LifetimeMarkingScreen renders the title and the new tier-policy subtitle',
    (tester) async {
      // Override the per-curriculum summary provider with an empty list so the
      // screen renders without a database — the title + subtitle live above
      // the curriculum cards and are independent of the summary content.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lifetimeSummariesProvider.overrideWith((ref, profileId) async {
              return const [];
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: LifetimeMarkingScreen(),
          ),
        ),
      );
      // Settle the FutureProvider override.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Title — uses the existing `addWhatYouLearned` key which conveys the
      // "Mark lifetime knowledge" concept (kept close to existing per
      // W5-D brief: "the design intent is clarity").
      expect(
        find.text("Add what you've learned"),
        findsOneWidget,
        reason:
            'The AppBar title must render via the addWhatYouLearned l10n key',
      );

      // New W5-D subtitle — must surface the full tier-policy copy verbatim
      // so the user understands the lifetimeOnly source and what it does NOT
      // credit toward.
      expect(
        find.text(
          "Items you've learned in your life, outside the app's tracks. "
          'Counted toward Lifetime Knowledge — not toward siyumim, streak, '
          'or points.',
        ),
        findsOneWidget,
        reason:
            'The lifetimeMarkingSubtitle key must render verbatim below the '
            'AppBar so the lifetimeOnly tier-credit policy is discoverable.',
      );
    },
  );
}
