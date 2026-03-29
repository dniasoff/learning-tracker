import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_grouped_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_timeline_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/milestone_badge.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/track_type_badge.dart';

void main() {
  group('TrackTypeBadge', () {
    testWidgets('displays personal track', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackTypeBadge(trackType: TrackType.personal)),
        ),
      );
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('displays school track', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackTypeBadge(trackType: TrackType.school)),
        ),
      );
      expect(find.text('School'), findsOneWidget);
    });

    testWidgets('displays tutor track', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackTypeBadge(trackType: TrackType.tutor)),
        ),
      );
      expect(find.text('Tutor'), findsOneWidget);
    });
  });

  group('MilestoneBadge', () {
    testWidgets('displays seder completion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MilestoneBadge(
              milestone: MilestoneAchievement(
                type: 'seder_complete',
                displayName: 'Zeraim',
                achievedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Seder Zeraim'), findsOneWidget);
    });

    testWidgets('displays curriculum completion with trophy icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MilestoneBadge(
              milestone: MilestoneAchievement(
                type: 'curriculum_complete',
                displayName: 'Mishnayos',
                achievedAt: DateTime(2026, 12, 1),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Completed Mishnayos'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });
  });

  group('JourneyGroupedView', () {
    testWidgets('shows curriculum name and progress', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 1, 1),
                completionNumber: 1,
                isManual: false,
              ),
            ],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [],
          ),
        ],
        totalCompletions: 1,
        totalUniqueUnits: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyGroupedView(viewModel: viewModel)),
        ),
      );

      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('1 of 63 units completed'), findsOneWidget);
      expect(find.text('Berakhot'), findsWidgets);
    });

    testWidgets('shows no completions message for empty curriculum', (
      tester,
    ) async {
      const viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: [],
            uniqueUnitsCompleted: 0,
            totalUnitsAvailable: 37,
            milestones: [],
          ),
        ],
        totalCompletions: 0,
        totalUniqueUnits: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: JourneyGroupedView(viewModel: viewModel)),
        ),
      );

      expect(find.text('No completions yet'), findsOneWidget);
    });

    testWidgets('shows milestone badges when present', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [],
            uniqueUnitsCompleted: 63,
            totalUnitsAvailable: 63,
            milestones: [
              MilestoneAchievement(
                type: 'curriculum_complete',
                displayName: 'Mishnayos',
                achievedAt: DateTime(2026, 12, 1),
              ),
            ],
          ),
        ],
        totalCompletions: 0,
        totalUniqueUnits: 63,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyGroupedView(viewModel: viewModel)),
        ),
      );

      expect(find.byType(MilestoneBadge), findsOneWidget);
    });

    testWidgets('shows multiple completion count', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 1, 1),
                completionNumber: 1,
                isManual: false,
              ),
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 6, 1),
                completionNumber: 2,
                isManual: false,
              ),
            ],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [],
          ),
        ],
        totalCompletions: 2,
        totalUniqueUnits: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyGroupedView(viewModel: viewModel)),
        ),
      );

      expect(find.textContaining('2 completions'), findsOneWidget);
    });
  });

  group('JourneyTimelineView', () {
    testWidgets('shows completions in chronological order', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 3, 15),
                completionNumber: 1,
                isManual: false,
              ),
              UnitCompletion(
                unitIdentifier: 'Shabbat',
                unitType: 'masechta',
                displayNameHe: 'שבת',
                displayNameEn: 'Shabbat',
                trackType: TrackType.school,
                completedAt: DateTime(2026, 1, 10),
                completionNumber: 1,
                isManual: false,
              ),
            ],
            uniqueUnitsCompleted: 2,
            totalUnitsAvailable: 63,
            milestones: [],
          ),
        ],
        totalCompletions: 2,
        totalUniqueUnits: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyTimelineView(viewModel: viewModel)),
        ),
      );

      // Month headers should appear
      expect(find.text('March 2026'), findsOneWidget);
      expect(find.text('January 2026'), findsOneWidget);
      // Entries should appear
      expect(find.text('Berakhot'), findsOneWidget);
      expect(find.text('Shabbat'), findsOneWidget);
    });

    testWidgets('shows empty message when no completions', (tester) async {
      const viewModel = JourneyViewModel(
        curricula: [],
        totalCompletions: 0,
        totalUniqueUnits: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: JourneyTimelineView(viewModel: viewModel)),
        ),
      );

      expect(find.text('No completions to show'), findsOneWidget);
    });

    testWidgets('shows track type badges', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.tutor,
                completedAt: DateTime(2026, 2, 1),
                completionNumber: 1,
                isManual: false,
              ),
            ],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 37,
            milestones: [],
          ),
        ],
        totalCompletions: 1,
        totalUniqueUnits: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyTimelineView(viewModel: viewModel)),
        ),
      );

      expect(find.byType(TrackTypeBadge), findsOneWidget);
      expect(find.text('Tutor'), findsOneWidget);
    });
  });
}
