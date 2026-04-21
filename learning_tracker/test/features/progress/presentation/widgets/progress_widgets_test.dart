import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/pace_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/stage_breakdown_row.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

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
    testWidgets('shows behind status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PaceIndicator(
            paceStatus: PaceStatus(
              status: PaceStatusType.behind,
              daysDelta: -5,
              rollingAverage: 2.0,
            ),
          ),
        ),
      );

      expect(find.text('Behind by 5 days'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('shows on-track status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PaceIndicator(
            paceStatus: PaceStatus(
              status: PaceStatusType.onPace,
              daysDelta: 0,
              rollingAverage: 3.0,
            ),
          ),
        ),
      );

      expect(find.text('On pace'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows ahead status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PaceIndicator(
            paceStatus: PaceStatus(
              status: PaceStatusType.ahead,
              daysDelta: 3,
              rollingAverage: 5.0,
            ),
          ),
        ),
      );

      expect(find.text('Ahead by 3 days'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
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
    testWidgets('renders with progress bar and percentage', (tester) async {
      const level = HierarchyLevelProgress(
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 10,
        completedItems: 5,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 5)],
        trackBreakdown: {
          TrackType.personal: 3,
          TrackType.personal: 2,
          TrackType.personal: 0,
        },
      );

      await tester.pumpWidget(_wrap(const HierarchyProgressCard(level: level)));

      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('5/10 (50%)'), findsOneWidget);
      expect(find.text('Learned: 5'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('expandable card shows sub-levels on tap', (tester) async {
      const level = HierarchyLevelProgress(
        levelName: 'Seder Zeraim',
        levelLabel: 'Seder',
        totalItems: 4,
        completedItems: 2,
        stageBreakdown: [StageBreakdownEntry(stageName: 'Learned', count: 2)],
        trackBreakdown: {
          TrackType.personal: 2,
          TrackType.personal: 0,
          TrackType.personal: 0,
        },
        subLevels: [
          HierarchyLevelProgress(
            levelName: 'Berachos',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 2,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 2),
            ],
            trackBreakdown: {
              TrackType.personal: 2,
              TrackType.personal: 0,
              TrackType.personal: 0,
            },
          ),
          HierarchyLevelProgress(
            levelName: 'Peah',
            levelLabel: 'Masechta',
            totalItems: 2,
            completedItems: 0,
            stageBreakdown: [
              StageBreakdownEntry(stageName: 'Learned', count: 0),
            ],
            trackBreakdown: {
              TrackType.personal: 0,
              TrackType.personal: 0,
              TrackType.personal: 0,
            },
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
