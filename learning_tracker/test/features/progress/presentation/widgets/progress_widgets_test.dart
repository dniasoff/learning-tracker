import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 10,
        completedItems: 5,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 5)],
        trackBreakdown: {TrackType.personal: 5},
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));

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
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 10,
        completedItems: 5,
        stageBreakdown: [
          StageBreakdownEntry(stageName: 'Learned', count: 5),
          StageBreakdownEntry(stageName: 'Chazara 1', count: 3),
        ],
        trackBreakdown: {TrackType.personal: 5},
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));

      expect(find.text('Seder Zeraim'), findsOneWidget);
      // Multi-stage: chazaros suffix appears (count = sum of stages after first).
      expect(find.textContaining('chazaros'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('expandable card shows sub-levels on tap', (tester) async {
      const level = HierarchyLevelProgress(
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 4,
        completedItems: 2,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 2)],
        trackBreakdown: {TrackType.personal: 2},
        subLevels: [
          HierarchyLevelProgress(
            levelName: 'Berachos',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 2,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 2),
            ],
            trackBreakdown: {TrackType.personal: 2},
          ),
          HierarchyLevelProgress(
            levelName: 'Peah',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 0,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 0),
            ],
            trackBreakdown: {TrackType.personal: 0},
          ),
        ],
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));

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
}
