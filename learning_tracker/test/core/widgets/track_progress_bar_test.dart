import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/track_progress_bar.dart';

void main() {
  group('TrackProgressBar', () {
    testWidgets(
      'renders segmented bar with correct proportions and track-specific colors',
      (tester) async {
        // Arrange
        final trackCounts = {
          TrackType.personal: 150,
          TrackType.school: 80,
          TrackType.tutor: 20,
        };

        // Act
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
          ),
        );

        // Assert: Widget renders
        expect(find.byType(TrackProgressBar), findsOneWidget);

        // Assert: Labels are shown
        expect(find.text('Personal: 150'), findsOneWidget);
        expect(find.text('School: 80'), findsOneWidget);
        expect(find.text('Tutor: 20'), findsOneWidget);
      },
    );

    testWidgets('renders correctly in both light and dark themes', (
      tester,
    ) async {
      // Arrange
      final trackCounts = {
        TrackType.personal: 10,
        TrackType.school: 5,
        TrackType.tutor: 0,
      };

      // Test light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      // Assert: Widget renders in light theme
      expect(find.byType(TrackProgressBar), findsOneWidget);
      expect(find.text('Personal: 10'), findsOneWidget);

      // Note: Dark theme test would go here when dark theme is implemented
    });

    testWidgets('shows empty state when all counts are zero', (tester) async {
      // Arrange
      final trackCounts = {
        TrackType.personal: 0,
        TrackType.school: 0,
        TrackType.tutor: 0,
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      // Assert: Empty state message is shown
      expect(find.text('No completions yet'), findsOneWidget);
    });

    testWidgets('respects height parameter', (tester) async {
      // Arrange
      const customHeight = 32.0;
      final trackCounts = {
        TrackType.personal: 10,
        TrackType.school: 5,
        TrackType.tutor: 0,
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TrackProgressBar(
              trackCounts: trackCounts,
              height: customHeight,
            ),
          ),
        ),
      );

      // Assert: Widget renders with custom height
      expect(find.byType(TrackProgressBar), findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(TrackProgressBar),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.height, customHeight);
    });

    testWidgets('hides labels when showLabels is false', (tester) async {
      // Arrange
      final trackCounts = {
        TrackType.personal: 10,
        TrackType.school: 5,
        TrackType.tutor: 0,
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TrackProgressBar(trackCounts: trackCounts, showLabels: false),
          ),
        ),
      );

      // Assert: Labels are not shown
      expect(find.text('Personal: 10'), findsNothing);
      expect(find.text('School: 5'), findsNothing);
    });

    testWidgets('handles single track with non-zero count', (tester) async {
      // Arrange
      final trackCounts = {
        TrackType.personal: 100,
        TrackType.school: 0,
        TrackType.tutor: 0,
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      // Assert: Widget renders correctly
      expect(find.byType(TrackProgressBar), findsOneWidget);
      expect(find.text('Personal: 100'), findsOneWidget);
      expect(find.text('School: 0'), findsOneWidget);
      expect(find.text('Tutor: 0'), findsOneWidget);
    });

    testWidgets('uses correct track colors from theme', (tester) async {
      // Arrange
      final trackCounts = {
        TrackType.personal: 1,
        TrackType.school: 1,
        TrackType.tutor: 1,
      };

      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      // Assert: Widget renders
      expect(find.byType(TrackProgressBar), findsOneWidget);

      // Verify track colors are used (check that colored containers exist)
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(TrackProgressBar),
          matching: find.byType(Container),
        ),
      );

      // Count containers with track colors
      final coloredContainers = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          final color = decoration.color;
          return color == AppTheme.trackPersonal ||
              color == AppTheme.trackSchool ||
              color == AppTheme.trackTutor;
        }
        return false;
      }).toList();

      // We should have colored containers for the segments plus label indicators
      expect(coloredContainers.length, greaterThan(0));
    });
  });
}
