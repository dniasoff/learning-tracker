import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/track_progress_bar.dart';

void main() {
  group('TrackProgressBar (v1 — personal only)', () {
    testWidgets('renders bar with personal-track count and label', (
      tester,
    ) async {
      final trackCounts = {TrackType.personal: 150};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      expect(find.byType(TrackProgressBar), findsOneWidget);
      expect(find.text('Personal: 150'), findsOneWidget);
    });

    testWidgets('shows empty state when count is zero', (tester) async {
      final trackCounts = {TrackType.personal: 0};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
        ),
      );

      expect(find.text('No completions yet'), findsOneWidget);
    });

    testWidgets('respects height parameter', (tester) async {
      const customHeight = 32.0;
      final trackCounts = {TrackType.personal: 10};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: TrackProgressBar(
              trackCounts: trackCounts,
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
      final trackCounts = {TrackType.personal: 10};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: TrackProgressBar(trackCounts: trackCounts, showLabels: false),
          ),
        ),
      );

      expect(find.text('Personal: 10'), findsNothing);
    });

    testWidgets('uses personal track color from theme', (tester) async {
      final trackCounts = {TrackType.personal: 1};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
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
          return decoration.color == AppTheme.trackPersonal;
        }
        return false;
      }).toList();

      expect(coloredContainers.length, greaterThan(0));
    });
  });
}
