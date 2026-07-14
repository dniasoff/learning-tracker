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

import '../../../../helpers/pump_app.dart';

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
      // "Mark lifetime knowledge" concept. The Wave-5 copy refresh renamed
      // the visible string to "Add Lifetime Learning" (matches the
      // sidebar entry); the key name stays for source-stability.
      expect(
        find.text('Add Lifetime Learning'),
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

  // ── he-RTL smoke (AUD-t-settings-06 / TQ-3) ─────────────────────────────
  //
  // The settings feature's convention (curriculum_settings_screen_l1_test.dart)
  // is that key screens carry a Hebrew/RTL smoke test. LifetimeMarkingScreen
  // had none, so Hebrew rendering and RTL layout were unverified. Pumps via
  // the shared test/helpers/pump_app.dart rig (TQ-3 Rule-0 — new call sites
  // must not hand-roll another MaterialApp(localizationsDelegates: [...])
  // block) under Locale('he') and asserts the resolved Directionality is RTL.
  group('LifetimeMarkingScreen — RTL smoke (he)', () {
    testWidgets('renders under Hebrew locale without crash and sets RTL '
        'text direction', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          locale: const Locale('he'),
          overrides: [
            lifetimeSummariesProvider.overrideWith((ref, profileId) async {
              return const [];
            }),
          ],
          child: const LifetimeMarkingScreen(),
        ),
      );
      // Settle the FutureProvider override.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      final dirFinders = find.byType(Directionality);
      expect(dirFinders, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinders.first);
      expect(
        outerDir.textDirection,
        TextDirection.rtl,
        reason:
            'Under the he locale the resolved Directionality must be RTL so '
            'Hebrew layout mirrors correctly.',
      );
    });
  });
}
