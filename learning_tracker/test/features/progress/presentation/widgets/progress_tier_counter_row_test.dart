/// Tests for [ProgressTierCounterRow] — the shared top-of-screen counter row
/// rendered by both the Progress hub and (Wave 4) the Dashboard.
///
/// Verifies:
///   - Adult mode: 3 counters (streak / siyumim / lifetime items).
///   - Child mode: 4 counters (adds points).
///   - Numbers reflect provider state (mocked).
@Tags(['progress', 'tier_counter'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/progress_tier_counter_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = 1;

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Pin the Hebrew Terms toggle off so we can assert against the English
/// default strings — the toggle's default depends on environment.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

JourneyViewModel _journey({
  int unit = 0,
  int aggregate = 0,
  int curriculum = 0,
}) => JourneyViewModel(
      curricula: const [],
      totalCompletions: 0,
      totalUniqueUnits: 0,
      unitLevelSiyumimCount: unit,
      aggregateLevelSiyumimCount: aggregate,
      curriculumLevelSiyumimCount: curriculum,
    );

LifetimeTotals _lifetime({int learned = 0, int total = 0}) => LifetimeTotals(
      learnedSections: learned,
      totalSections: total,
      totalCurricula: 9,
    );

Widget _wrap({
  required bool showPoints,
  required int currentStreak,
  required JourneyViewModel journey,
  required LifetimeTotals totals,
  int points = 0,
}) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: false),
      ),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value(
          (currentStreak: currentStreak, maxStreak: currentStreak),
        ),
      ),
      journeyViewModelProvider(_profileId).overrideWith(
        (ref) => Future.value(journey),
      ),
      lifetimeTotalsAcrossAllCurriculaProvider(_profileId).overrideWith(
        (ref) => Future.value(totals),
      ),
      dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(points)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ProgressTierCounterRow(showPoints: showPoints),
        ),
      ),
    ),
  );
}

void main() {
  group('ProgressTierCounterRow', () {
    testWidgets(
      'adult mode renders three counters (streak / siyumim / lifetime)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            showPoints: false,
            currentStreak: 6,
            // 3 unit + 1 aggregate + 0 curriculum = 4 siyumim total.
            journey: _journey(unit: 3, aggregate: 1, curriculum: 0),
            totals: _lifetime(learned: 1336),
            points: 250,
          ),
        );
        await tester.pumpAndSettle();

        // Counter labels (English default).
        expect(find.text('6-day streak'), findsOneWidget);
        expect(find.text('4 siyumim earned'), findsOneWidget);
        expect(find.text('1336 items in lifetime'), findsOneWidget);
        // Points must NOT appear in adult mode even if a non-zero value is
        // provided — the row gates on [showPoints].
        expect(find.text('250 pts'), findsNothing);
      },
    );

    testWidgets(
      'child mode renders four counters (adds points)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            showPoints: true,
            currentStreak: 2,
            journey: _journey(unit: 1, aggregate: 0, curriculum: 0),
            totals: _lifetime(learned: 5),
            points: 1250,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2-day streak'), findsOneWidget);
        expect(find.text('1 siyumim earned'), findsOneWidget);
        expect(find.text('5 items in lifetime'), findsOneWidget);
        expect(find.text('1250 pts'), findsOneWidget);
      },
    );

    testWidgets(
      'siyumim counter sums all three celebration levels',
      (tester) async {
        // 7 unit + 2 aggregate + 1 curriculum = 10 siyumim total.
        await tester.pumpWidget(
          _wrap(
            showPoints: false,
            currentStreak: 0,
            journey: _journey(unit: 7, aggregate: 2, curriculum: 1),
            totals: _lifetime(learned: 0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('10 siyumim earned'), findsOneWidget);
      },
    );

    testWidgets(
      'zero state renders cleanly (no crash, all zeros visible)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            showPoints: true,
            currentStreak: 0,
            journey: _journey(),
            totals: _lifetime(),
            points: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0-day streak'), findsOneWidget);
        expect(find.text('0 siyumim earned'), findsOneWidget);
        expect(find.text('0 items in lifetime'), findsOneWidget);
        expect(find.text('0 pts'), findsOneWidget);
      },
    );

    // F17 regression — during the first paint while the dependent providers
    // are still loading, the row must render the "…" placeholder NOT zeros.
    // The legacy fallback `streakAsync.asData?.value.currentStreak ?? 0`
    // produced "0-day streak · 0 siyumim earned · 0 items in lifetime" for
    // the brief async window — exactly the "1336 vs 0" confusion the IA
    // redesign was meant to eliminate.
    testWidgets(
      'placeholder ("…") shown while every provider is loading',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeProfileIdProvider.overrideWith(
                () => _ProfileIdOverride(_profileId),
              ),
              useHebrewTermsProvider.overrideWith(
                () => _UseHebrewTermsOverride(useHebrew: false),
              ),
              // Hold every provider in the loading state by returning futures
              // and streams that never complete. The widget should NOT fall
              // back to zeros — it should render the "…" placeholder until
              // every dependency resolves.
              dashboardStreakProvider.overrideWith(
                (ref) => const Stream.empty(),
              ),
              journeyViewModelProvider(_profileId).overrideWith(
                (ref) => Completer<JourneyViewModel>().future,
              ),
              lifetimeTotalsAcrossAllCurriculaProvider(_profileId)
                  .overrideWith(
                (ref) => Completer<LifetimeTotals>().future,
              ),
              dashboardGlobalPointsProvider.overrideWith(
                (ref) => Completer<int>().future,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: ProgressTierCounterRow(showPoints: true),
                ),
              ),
            ),
          ),
        );
        // Single pump — DO NOT pumpAndSettle because the providers are
        // intentionally never-completing futures.
        await tester.pump();

        // Each counter must show the placeholder, NOT a zero — three "…"
        // for adult (streak/siyumim/lifetime) + one more for points = 4.
        expect(
          find.text('…'),
          findsNWidgets(4),
          reason:
              'loading state must render the placeholder for all four '
              'counter values, not fall back to misleading zeros',
        );
      },
    );

    // F17 partial-loading — when one provider has resolved but others are
    // still loading, every counter VALUE must stay on the placeholder. The
    // visual sin we're guarding against: a flashy big "7" rendered next to
    // two stale zeros, suggesting "7 streak · 0 siyumim · 0 items" while
    // the real data is still en route.
    testWidgets(
      'placeholder is shown even when only ONE provider is still loading',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeProfileIdProvider.overrideWith(
                () => _ProfileIdOverride(_profileId),
              ),
              useHebrewTermsProvider.overrideWith(
                () => _UseHebrewTermsOverride(useHebrew: false),
              ),
              // Three providers ready, one still loading. The row must
              // remain in loading mode rather than rendering "7 · 0 · 0".
              dashboardStreakProvider.overrideWith(
                (ref) => Stream.value(
                  (currentStreak: 7, maxStreak: 7),
                ),
              ),
              journeyViewModelProvider(_profileId).overrideWith(
                (ref) => Future.value(_journey(unit: 3)),
              ),
              lifetimeTotalsAcrossAllCurriculaProvider(_profileId)
                  .overrideWith(
                (ref) => Completer<LifetimeTotals>().future,
              ),
              dashboardGlobalPointsProvider.overrideWith(
                (ref) => Future.value(42),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: ProgressTierCounterRow(showPoints: true),
                ),
              ),
            ),
          ),
        );
        // Pump once to let the stream + ready futures emit their values
        // without waiting on the still-pending lifetime totals future.
        await tester.pump();
        await tester.pump();

        // No counter VALUE should render as a real number yet — the lifetime
        // provider is still loading, so the gate stays closed for all four
        // slots. All four numeric slots show the placeholder. The descriptive
        // labels (e.g. "7-day streak") may still embed the resolved count
        // for plural-form purposes; that's tiny text, the visual gate is on
        // the big value.
        expect(find.text('…'), findsNWidgets(4));
      },
    );
  });
}
