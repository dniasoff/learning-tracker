import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/track_management_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackRepository extends Mock implements TrackRepository {}

void main() {
  late MockTrackRepository mockRepository;

  setUp(() {
    mockRepository = MockTrackRepository();
  });

  Widget createTestWidget({required List<TrackType> initialActiveTracks}) {
    return ProviderScope(
      overrides: [
        trackRepositoryProvider.overrideWithValue(mockRepository),
        activeTracksProvider(
          CurriculumId.mishnayos,
        ).overrideWith((ref) => Future.value(initialActiveTracks)),
      ],
      child: const MaterialApp(
        home: TrackManagementScreen(curriculumId: 'mishnayos'),
      ),
    );
  }

  group('TrackManagementScreen Widget Tests', () {
    testWidgets(
      'renders toggle switches for school and tutor tracks, personal track shown as always-on',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialActiveTracks: [TrackType.personal]),
        );
        await tester.pumpAndSettle();

        // Find all switches
        final switches = find.byType(SwitchListTile);
        expect(switches, findsNWidgets(3)); // personal, school, tutor

        // Find personal track
        final personalSwitch = find.ancestor(
          of: find.text('Personal'),
          matching: find.byType(SwitchListTile),
        );
        expect(personalSwitch, findsOneWidget);

        // Verify personal track is on and disabled
        final personalSwitchWidget = tester.widget<SwitchListTile>(
          personalSwitch,
        );
        expect(personalSwitchWidget.value, isTrue);
        expect(personalSwitchWidget.onChanged, isNull); // Disabled

        // Find subtitle showing "Always active"
        expect(find.text('Always active'), findsOneWidget);

        // Find school and tutor tracks
        expect(find.text('School'), findsOneWidget);
        expect(find.text('Tutor'), findsOneWidget);
      },
    );

    testWidgets('school track toggle is enabled when inactive', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActiveTracks: [TrackType.personal]),
      );
      await tester.pumpAndSettle();

      final schoolSwitch = find.ancestor(
        of: find.text('School'),
        matching: find.byType(SwitchListTile),
      );
      final schoolSwitchWidget = tester.widget<SwitchListTile>(schoolSwitch);

      expect(schoolSwitchWidget.value, isFalse);
      expect(schoolSwitchWidget.onChanged, isNotNull); // Enabled
    });

    testWidgets('tutor track toggle is enabled when inactive', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActiveTracks: [TrackType.personal]),
      );
      await tester.pumpAndSettle();

      final tutorSwitch = find.ancestor(
        of: find.text('Tutor'),
        matching: find.byType(SwitchListTile),
      );
      final tutorSwitchWidget = tester.widget<SwitchListTile>(tutorSwitch);

      expect(tutorSwitchWidget.value, isFalse);
      expect(tutorSwitchWidget.onChanged, isNotNull); // Enabled
    });

    testWidgets('activating school track calls repository', (tester) async {
      when(
        () => mockRepository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        ),
      ).thenAnswer((_) async => {});

      await tester.pumpWidget(
        createTestWidget(initialActiveTracks: [TrackType.personal]),
      );
      await tester.pumpAndSettle();

      // Tap school track switch
      final schoolSwitch = find.ancestor(
        of: find.text('School'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(schoolSwitch);
      await tester.pumpAndSettle();

      verify(
        () => mockRepository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        ),
      ).called(1);
    });

    testWidgets(
      'deactivating track shows confirmation dialog warning that data is preserved',
      (tester) async {
        when(
          () => mockRepository.deactivateTrack(
            CurriculumId.mishnayos,
            TrackType.school,
          ),
        ).thenAnswer((_) async => {});

        await tester.pumpWidget(
          createTestWidget(
            initialActiveTracks: [TrackType.personal, TrackType.school],
          ),
        );
        await tester.pumpAndSettle();

        // Tap school track switch (to deactivate)
        final schoolSwitch = find.ancestor(
          of: find.text('School'),
          matching: find.byType(SwitchListTile),
        );
        await tester.tap(schoolSwitch);
        await tester.pumpAndSettle();

        // Verify confirmation dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Deactivate Track?'), findsOneWidget);
        expect(
          find.textContaining('completion history will be preserved'),
          findsOneWidget,
        );

        // Verify dialog has Cancel and Deactivate buttons
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Deactivate'), findsOneWidget);
      },
    );

    testWidgets('canceling deactivation does not call repository', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActiveTracks: [TrackType.personal, TrackType.school],
        ),
      );
      await tester.pumpAndSettle();

      // Tap school track switch
      final schoolSwitch = find.ancestor(
        of: find.text('School'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(schoolSwitch);
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify repository was NOT called
      verifyNever(
        () => mockRepository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        ),
      );
    });

    testWidgets('confirming deactivation calls repository', (tester) async {
      when(
        () => mockRepository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        ),
      ).thenAnswer((_) async => {});

      await tester.pumpWidget(
        createTestWidget(
          initialActiveTracks: [TrackType.personal, TrackType.school],
        ),
      );
      await tester.pumpAndSettle();

      // Tap school track switch
      final schoolSwitch = find.ancestor(
        of: find.text('School'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(schoolSwitch);
      await tester.pumpAndSettle();

      // Tap Deactivate button
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      // Verify repository was called
      verify(
        () => mockRepository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        ),
      ).called(1);
    });

    testWidgets('shows all three tracks when multiple active', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActiveTracks: [
            TrackType.personal,
            TrackType.school,
            TrackType.tutor,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // All three tracks should be visible
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Tutor'), findsOneWidget);

      // School and tutor should show "Active" subtitle
      expect(find.text('Active'), findsNWidgets(2));

      // Personal should show "Always active"
      expect(find.text('Always active'), findsOneWidget);
    });
  });
}
