import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_grouped_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_timeline_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/milestone_badge.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/track_type_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {bool hebrewTermsScript = true}) {
  SharedPreferences.setMockInitialValues({
    'hebrew_terms_script_p0': hebrewTermsScript,
  });
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Build a test [UnitCompletion] with new structural keys.
UnitCompletion _completion({
  String identifier = 'Berakhot',
  String scope = 'masechta',
  String? parentL1 = 'Zeraim',
  TrackType trackType = TrackType.personal,
  DateTime? completedAt,
  int completionNumber = 1,
  bool isManual = false,
}) {
  return UnitCompletion(
    unitIdentifier: identifier,
    unitType: scope,
    entryScope: scope,
    entryKey: identifier,
    parentL1Key: parentL1,
    trackType: trackType,
    completedAt: completedAt ?? DateTime(2026, 1, 1),
    completionNumber: completionNumber,
    isManual: isManual,
  );
}

void main() {
  group('TrackTypeBadge', () {
    testWidgets('displays personal track', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackTypeBadge(trackType: TrackType.personal),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('displays personal track badge color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackTypeBadge(trackType: TrackType.personal),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('personal badge is styled with a Container', (tester) async {
      await tester.pumpWidget(
        _wrap(const TrackTypeBadge(trackType: TrackType.personal)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Container), findsWidgets);
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
              _completion(identifier: 'Berakhot'),
            ],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [],
          ),
        ],
        totalCompletions: 1,
        totalUniqueUnits: 1,
      );

      await tester.pumpWidget(_wrap(JourneyGroupedView(viewModel: viewModel)));
      await tester.pumpAndSettle();

      // Curriculum name rendered via CurriculumLabel.curriculum (Hebrew mode)
      expect(find.text('משניות'), findsWidgets);
      expect(find.text('1 of 63 units completed'), findsOneWidget);
      // Entry key rendered via CurriculumLabel.level (no hebrewName → rawValue)
      expect(find.textContaining('Berakhot'), findsWidgets);
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
        _wrap(const JourneyGroupedView(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(_wrap(JourneyGroupedView(viewModel: viewModel)));
      await tester.pumpAndSettle();

      expect(find.byType(MilestoneBadge), findsOneWidget);
    });

    testWidgets('shows multiple completion count', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              _completion(
                identifier: 'Berakhot',
                completedAt: DateTime(2026, 1, 1),
                completionNumber: 1,
              ),
              _completion(
                identifier: 'Berakhot',
                completedAt: DateTime(2026, 6, 1),
                completionNumber: 2,
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

      await tester.pumpWidget(_wrap(JourneyGroupedView(viewModel: viewModel)));
      await tester.pumpAndSettle();

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
              _completion(
                identifier: 'Berakhot',
                completedAt: DateTime(2026, 3, 15),
                completionNumber: 1,
              ),
              _completion(
                identifier: 'Shabbat',
                completedAt: DateTime(2026, 1, 10),
                completionNumber: 1,
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

      await tester.pumpWidget(_wrap(JourneyTimelineView(viewModel: viewModel)));
      await tester.pumpAndSettle();

      // Month headers should appear
      expect(find.text('March 2026'), findsOneWidget);
      expect(find.text('January 2026'), findsOneWidget);
      // Entries rendered via CurriculumLabel.level — rawValue shown without hebrewName
      expect(find.textContaining('Berakhot'), findsOneWidget);
      expect(find.textContaining('Shabbat'), findsOneWidget);
    });

    testWidgets('shows empty message when no completions', (tester) async {
      const viewModel = JourneyViewModel(
        curricula: [],
        totalCompletions: 0,
        totalUniqueUnits: 0,
      );

      await tester.pumpWidget(
        _wrap(const JourneyTimelineView(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No completions to show'), findsOneWidget);
    });

    testWidgets('shows track type badges', (tester) async {
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: [
              _completion(
                identifier: 'Berakhot',
                completedAt: DateTime(2026, 2, 1),
                completionNumber: 1,
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
        _wrap(
          JourneyTimelineView(viewModel: viewModel),
          hebrewTermsScript: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrackTypeBadge), findsWidgets);
      expect(find.text('Personal'), findsOneWidget);
    });
  });
}
