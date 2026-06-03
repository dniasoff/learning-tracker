import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/pace_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/stage_breakdown_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Forces the Hebrew Terms toggle to OFF so the English assertions below
/// remain stable — the production default is ON in seeded environments.
class _UseHebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Hebrew Terms ON — for the "Breakdown by Level" name-rendering matrix.
class _UseHebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _VariantAshkenazi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

class _VariantSephardi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [useHebrewTermsProvider.overrideWith(_UseHebrewTermsOff.new)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

// Reference date for PaceCalculator fixtures.
final _today = DateTime(2026, 5, 20);

void main() {
  group('StageBreakdownRow', () {
    testWidgets('displays correct label text and counts for each stage', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StageBreakdownRow(
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 15),
              StageBreakdownEntry(stageName: 'Chazara 1', count: 8),
              StageBreakdownEntry(stageName: 'Chazara 2', count: 3),
            ],
          ),
        ),
      );

      expect(find.text('Learned: 15'), findsOneWidget);
      expect(find.text('Chazara 1: 8'), findsOneWidget);
      expect(find.text('Chazara 2: 3'), findsOneWidget);
    });
  });

  group('PaceIndicator', () {
    // -----------------------------------------------------------------------
    // Helper: create a PaceCalculator for a track started N days ago
    // with the given liveProgress.
    // totalItems=200, bulkBaseline=0, targetDate= trackStart+100 days.
    // -----------------------------------------------------------------------
    PaceCalculator makePace({
      required int elapsedDays,
      required int liveProgress,
      int bulkBaseline = 0,
    }) {
      final trackStart = _today.subtract(Duration(days: elapsedDays));
      return PaceCalculator.compute(
        totalItems: 200,
        bulkBaseline: bulkBaseline,
        liveProgress: liveProgress,
        trackStartDate: trackStart,
        targetDate: trackStart.add(const Duration(days: 100)),
        today: _today,
      );
    }

    testWidgets('shows behind status', (tester) async {
      // elapsed=10, requiredVelocity=2/day, expected=20, live=0 → variance=-20
      // paceVarianceInDays = -20/2 = -10 → behind by 10 days
      await tester.pumpWidget(
        _wrap(PaceIndicator(pace: makePace(elapsedDays: 10, liveProgress: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Behind by 10 days'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });

    testWidgets('shows on-track status', (tester) async {
      // elapsed=10, requiredVelocity=2/day, expected=20, live=20 → variance=0 → onTrack
      await tester.pumpWidget(
        _wrap(PaceIndicator(pace: makePace(elapsedDays: 10, liveProgress: 20))),
      );
      await tester.pumpAndSettle();

      expect(find.text('On pace'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows ahead status', (tester) async {
      // elapsed=10, requiredVelocity=2/day, expected=20, live=40
      // paceVariance=20, paceVarianceInDays=20/2=10 → ahead by 10 days
      await tester.pumpWidget(
        _wrap(PaceIndicator(pace: makePace(elapsedDays: 10, liveProgress: 40))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahead by 10 days'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('grace window shows "On track" (not "Ahead by 0 days")', (
      tester,
    ) async {
      // Day 1 (elapsed=1 == kPaceGraceWindowDays) → graceWindow → "On pace"
      await tester.pumpWidget(
        _wrap(
          PaceIndicator(
            // 1336 bulk baseline, 0 live → Mishnayos-bug fixture
            pace: PaceCalculator.compute(
              totalItems: 1336,
              bulkBaseline: 1336,
              liveProgress: 0,
              trackStartDate: _today,
              targetDate: _today.add(const Duration(days: 365)),
              today: _today,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must show "On pace" from the graceWindow branch — NOT "Ahead by 0 days"
      expect(find.text('On pace'), findsOneWidget);
      expect(find.textContaining('Ahead'), findsNothing);
      expect(find.textContaining('Behind'), findsNothing);
    });
  });

  group('OverallStatsCard', () {
    testWidgets('displays all stat categories', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OverallStatsCard(
            stats: OverallCurriculumStats(
              totalItems: 100,
              completedAllStages: 25,
              inProgress: 30,
              notStarted: 45,
            ),
          ),
        ),
      );

      expect(find.text('Overall Progress'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Total items'), findsOneWidget);
      expect(find.text('Completed all stages'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
    });
  });

  group('HierarchyProgressCard', () {
    testWidgets('single-stage track shows subtitle without chazaros suffix', (
      tester,
    ) async {
      // Rule 8: chazara entries are those AFTER the first stage. When only
      // the learn stage exists, the chazaros suffix is omitted entirely.
      const level = HierarchyLevelProgress(
        curriculumId: CurriculumId.mishnayos,
        level: 1,
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 10,
        completedItems: 5,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 5)],
        trackBreakdown: {'personal': 5},
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));
      await tester.pumpAndSettle();

      // English (Ashkenazi default) mode: the level-1 seder key transliterates
      // through the shared renderer; "Seder Zeraim" is identical in both
      // nuschaos so it passes through unchanged.
      expect(find.text('Seder Zeraim'), findsOneWidget);
      // Single-stage: no chazara column, so subtitle is progress-only.
      expect(find.text('5/10 (50%)'), findsOneWidget);
      expect(find.textContaining('chazaros'), findsNothing);
      expect(find.text('Learned: 5'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('multi-stage track shows subtitle with chazaros count', (
      tester,
    ) async {
      // When a second stage (chazara) exists, the chazaros count is shown.
      const level = HierarchyLevelProgress(
        curriculumId: CurriculumId.mishnayos,
        level: 1,
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 10,
        completedItems: 5,
        stageBreakdown: [
          StageBreakdownEntry(stageName: 'Learned', count: 5),
          StageBreakdownEntry(stageName: 'Chazara 1', count: 3),
        ],
        trackBreakdown: {'personal': 5},
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));
      await tester.pumpAndSettle();

      expect(find.text('Seder Zeraim'), findsOneWidget);
      // Multi-stage: chazaros suffix appears (count = sum of stages after first).
      expect(find.textContaining('chazaros'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('expandable card shows sub-levels on tap', (tester) async {
      const level = HierarchyLevelProgress(
        curriculumId: CurriculumId.mishnayos,
        level: 1,
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 4,
        completedItems: 2,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 2)],
        trackBreakdown: {'personal': 2},
        subLevels: [
          HierarchyLevelProgress(
            curriculumId: CurriculumId.mishnayos,
            level: 2,
            levelName: 'Berachos',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 2,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 2),
            ],
            trackBreakdown: {'personal': 2},
          ),
          HierarchyLevelProgress(
            curriculumId: CurriculumId.mishnayos,
            level: 2,
            levelName: 'Peah',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 0,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 0),
            ],
            trackBreakdown: {'personal': 0},
          ),
        ],
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));
      await tester.pumpAndSettle();

      // Sub-levels not visible initially
      expect(find.text('Berachos'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Seder Zeraim'));
      await tester.pumpAndSettle();

      // Sub-levels visible
      expect(find.text('Berachos'), findsOneWidget);
      expect(find.text('Peah'), findsOneWidget);
    });
  });

  group('HierarchyProgressCard — level name follows the rendering contract', () {
    // Mishnayos seder containers as they live in the bundled content asset:
    // the raw level1 storage key carries the "Seder " prefix, and the content
    // row supplies the Hebrew name. The Progress "Breakdown by Level" title
    // MUST resolve the raw key through the shared renderer — Hebrew script
    // when Hebrew-terms is ON, the nusach-appropriate transliteration when OFF
    // — instead of leaking the raw English key (the confirmed bug).
    const zeraim = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      displayNameHe: 'סדר זרעים',
      displayNameEn: 'Seder Zeraim',
      sefariaRef: 'Seder Zeraim',
      sortOrder: 0,
      isLeaf: false,
    );
    // Tahoros/Tahorot is the ONE seder that differs across nuschaos, so it
    // proves the transliteration-variant path (the rest are identical).
    const tahoros = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Tahorot',
      displayNameHe: 'סדר טהרות',
      displayNameEn: 'Seder Tahorot',
      sefariaRef: 'Seder Tahorot',
      sortOrder: 1,
      isLeaf: false,
    );

    Widget host({
      required HierarchyLevelProgress level,
      required bool useHebrewTerms,
      required TransliterationVariant variant,
      Locale? locale,
    }) {
      return ProviderScope(
        overrides: [
          useHebrewTermsProvider.overrideWith(
            useHebrewTerms ? _UseHebrewTermsOn.new : _UseHebrewTermsOff.new,
          ),
          currentTransliterationVariantProvider.overrideWith(
            variant == TransliterationVariant.sephardi
                ? _VariantSephardi.new
                : _VariantAshkenazi.new,
          ),
          curriculumContentProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) async => const [zeraim, tahoros]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: SingleChildScrollView(child: child(level))),
        ),
      );
    }

    HierarchyLevelProgress sederLevel(String rawLevelName) =>
        HierarchyLevelProgress(
          curriculumId: CurriculumId.mishnayos,
          level: 1,
          levelName: rawLevelName,
          levelLabel: 'Seder',
          totalItems: 10,
          completedItems: 5,
          stageBreakdown: const [
            StageBreakdownEntry(stageName: 'Learned', count: 5),
          ],
          trackBreakdown: const {'personal': 5},
        );

    testWidgets('Hebrew-terms ON renders the Hebrew seder name (Zeraim)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          level: sederLevel('Seder Zeraim'),
          useHebrewTerms: true,
          variant: TransliterationVariant.ashkenazi,
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();

      // The shared renderer strips the structural "סדר " prefix from the
      // Hebrew name (the canonical contract — see curriculum_label_renderer
      // test), so Zeraim resolves to its bare Hebrew name.
      expect(find.text('זרעים'), findsOneWidget);
      // The raw English storage key must NOT leak.
      expect(find.text('Seder Zeraim'), findsNothing);
    });

    testWidgets(
      'Hebrew-terms OFF + Ashkenazi renders "Seder Taharos" (variant proof)',
      (tester) async {
        await tester.pumpWidget(
          host(
            level: sederLevel('Seder Tahorot'),
            useHebrewTerms: false,
            variant: TransliterationVariant.ashkenazi,
          ),
        );
        await tester.pumpAndSettle();

        // Ashkenazi transliteration of the only nusach-divergent seder.
        expect(find.text('Seder Taharos'), findsOneWidget);
        expect(find.text('Seder Tahorot'), findsNothing);
        // No Hebrew leaks in English mode.
        expect(find.text('סדר טהרות'), findsNothing);
      },
    );

    testWidgets(
      'Hebrew-terms OFF + Sephardi renders "Seder Tahorot" (variant proof)',
      (tester) async {
        await tester.pumpWidget(
          host(
            level: sederLevel('Seder Tahorot'),
            useHebrewTerms: false,
            variant: TransliterationVariant.sephardi,
          ),
        );
        await tester.pumpAndSettle();

        // Sephardi transliteration keeps "Tahorot".
        expect(find.text('Seder Tahorot'), findsOneWidget);
        expect(find.text('Seder Taharos'), findsNothing);
      },
    );

    testWidgets(
      'Hebrew-terms OFF + Ashkenazi renders identical-across-nusach seder '
      '("Seder Zeraim") unchanged',
      (tester) async {
        await tester.pumpWidget(
          host(
            level: sederLevel('Seder Zeraim'),
            useHebrewTerms: false,
            variant: TransliterationVariant.ashkenazi,
          ),
        );
        await tester.pumpAndSettle();

        // Zeraim is identical in both nuschaos — passes through unchanged.
        expect(find.text('Seder Zeraim'), findsOneWidget);
      },
    );
  });
}

/// Wraps [HierarchyProgressCard] for the rendering-contract group above.
Widget child(HierarchyLevelProgress level) =>
    HierarchyProgressCard(level: level);
