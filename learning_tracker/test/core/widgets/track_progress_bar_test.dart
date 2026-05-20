import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/track_progress_bar.dart';

void main() {
  group('TrackProgressBar', () {
    testWidgets('renders bar with completion count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: TrackProgressBar(completionCount: 150),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrackProgressBar), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('shows empty state when count is zero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: TrackProgressBar(completionCount: 0),
          ),
        ),
      );

      expect(find.text('No completions yet'), findsOneWidget);
    });

    testWidgets('respects height parameter', (tester) async {
      const customHeight = 32.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: TrackProgressBar(
              completionCount: 10,
              height: customHeight,
            ),
          ),
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: TrackProgressBar(
              completionCount: 10,
              showLabels: false,
            ),
          ),
        ),
      );

      expect(find.text('10'), findsNothing);
    });

    testWidgets('uses brand blue color from theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const Scaffold(
            body: TrackProgressBar(completionCount: 1),
          ),
        ),
      );

      expect(find.byType(TrackProgressBar), findsOneWidget);

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(TrackProgressBar),
          matching: find.byType(Container),
        ),
      );

      final coloredContainers = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == AppTheme.brandBlue;
        }
        return false;
      }).toList();

      expect(coloredContainers.length, greaterThan(0));
    });
  });
}
