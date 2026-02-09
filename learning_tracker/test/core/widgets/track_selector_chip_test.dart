import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/widgets/track_selector_chip.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';

void main() {
  Widget createTestWidget({
    required List<TrackType> activeTracks,
    TrackType? selectedTrack,
    required ValueChanged<TrackType> onTrackSelected,
  }) {
    return ProviderScope(
      overrides: [
        activeTracksProvider(CurriculumId.mishnayos).overrideWith(
          (ref) => Future.value(activeTracks),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrackSelectorChip(
            curriculumId: CurriculumId.mishnayos,
            selectedTrack: selectedTrack,
            onTrackSelected: onTrackSelected,
          ),
        ),
      ),
    );
  }

  group('TrackSelectorChip Widget Tests', () {
    testWidgets('displays only active tracks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal, TrackType.school],
          selectedTrack: TrackType.personal,
          onTrackSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Should show Personal and School chips
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);

      // Should NOT show Tutor chip (not active)
      expect(find.text('Tutor'), findsNothing);
    });

    testWidgets('highlights the currently selected track', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal, TrackType.school],
          selectedTrack: TrackType.personal,
          onTrackSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Find Personal choice chip
      final personalChip = find.ancestor(
        of: find.text('Personal'),
        matching: find.byType(ChoiceChip),
      );
      expect(personalChip, findsOneWidget);

      // Verify it's selected
      final personalChipWidget = tester.widget<ChoiceChip>(personalChip);
      expect(personalChipWidget.selected, isTrue);

      // Find School choice chip
      final schoolChip = find.ancestor(
        of: find.text('School'),
        matching: find.byType(ChoiceChip),
      );
      expect(schoolChip, findsOneWidget);

      // Verify it's not selected
      final schoolChipWidget = tester.widget<ChoiceChip>(schoolChip);
      expect(schoolChipWidget.selected, isFalse);
    });

    testWidgets('shows simple chip when only one track active', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal],
          selectedTrack: null,
          onTrackSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Should show a simple Chip (not ChoiceChip) for single track
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);

      // Should show Personal with check icon
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows ChoiceChips when multiple tracks active',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal, TrackType.school, TrackType.tutor],
          selectedTrack: TrackType.school,
          onTrackSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Should show ChoiceChips for all three tracks
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Tutor'), findsOneWidget);
    });

    testWidgets('calls onTrackSelected when chip is tapped', (tester) async {
      TrackType? selectedType;

      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal, TrackType.school],
          selectedTrack: TrackType.personal,
          onTrackSelected: (type) => selectedType = type,
        ),
      );
      await tester.pumpAndSettle();

      // Tap School chip
      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();

      expect(selectedType, TrackType.school);
    });

    testWidgets('updates selection when tapping different chip',
        (tester) async {
      TrackType? currentSelection = TrackType.personal;

      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [TrackType.personal, TrackType.school, TrackType.tutor],
          selectedTrack: currentSelection,
          onTrackSelected: (type) => currentSelection = type,
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Personal selected
      final personalChip = find.ancestor(
        of: find.text('Personal'),
        matching: find.byType(ChoiceChip),
      );
      expect(
        tester.widget<ChoiceChip>(personalChip).selected,
        isTrue,
      );

      // Tap Tutor chip
      await tester.tap(find.text('Tutor'));
      await tester.pumpAndSettle();

      expect(currentSelection, TrackType.tutor);
    });

    testWidgets('shows nothing when no active tracks', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          activeTracks: [],
          selectedTrack: null,
          onTrackSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Should show nothing (SizedBox.shrink)
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('handles loading state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTracksProvider(CurriculumId.mishnayos).overrideWith(
              (ref) => Future.delayed(
                const Duration(milliseconds: 100),
                () => [TrackType.personal],
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TrackSelectorChip(
                curriculumId: CurriculumId.mishnayos,
                selectedTrack: null,
                onTrackSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for data to load
      await tester.pumpAndSettle();

      // Loading indicator should be gone, chip should appear
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('handles error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTracksProvider(CurriculumId.mishnayos).overrideWith(
              (ref) => Future.error('Failed to load tracks'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TrackSelectorChip(
                curriculumId: CurriculumId.mishnayos,
                selectedTrack: null,
                onTrackSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show nothing on error (SizedBox.shrink)
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });
}
