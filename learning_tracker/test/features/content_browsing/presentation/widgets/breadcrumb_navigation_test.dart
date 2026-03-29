import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';

void main() {
  Widget createTestWidget({
    required List<String> navigationStack,
    required void Function(int) onBreadcrumbTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BreadcrumbNavigation(
          curriculum: CurriculumId.mishnayos,
          levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
          navigationStack: navigationStack,
          onBreadcrumbTap: onBreadcrumbTap,
        ),
      ),
    );
  }

  group('BreadcrumbNavigation', () {
    testWidgets('shows curriculum name as root level', (tester) async {
      await tester.pumpWidget(
        createTestWidget(navigationStack: [], onBreadcrumbTap: (_) {}),
      );

      expect(find.text('משניות'), findsOneWidget);
    });

    testWidgets('displays navigation stack with separators', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos'],
          onBreadcrumbTap: (_) {},
        ),
      );

      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Berachos'), findsOneWidget);

      // Should have chevron separators
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('makes previous levels clickable', (tester) async {
      var tappedLevel = -1;

      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos', 'Perek 1'],
          onBreadcrumbTap: (level) => tappedLevel = level,
        ),
      );

      // Tap on first level (Seder Zeraim)
      await tester.tap(find.text('Seder Zeraim'));
      expect(tappedLevel, 0);

      // Tap on second level (Berachos)
      await tester.tap(find.text('Berachos'));
      expect(tappedLevel, 1);
    });

    testWidgets('makes current level non-clickable with different style', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos'],
          onBreadcrumbTap: (_) {},
        ),
      );

      // Find the current level text widget
      final currentLevelFinder = find.text('Berachos');
      expect(currentLevelFinder, findsOneWidget);

      // Current level should be styled differently (bold, primary color)
      final textWidget = tester.widget<Text>(currentLevelFinder);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('handles empty navigation stack', (tester) async {
      await tester.pumpWidget(
        createTestWidget(navigationStack: [], onBreadcrumbTap: (_) {}),
      );

      // Should only show curriculum name
      expect(find.text('משניות'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('handles maximum depth (4 levels)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos', 'Perek 1', 'Mishna 1'],
          onBreadcrumbTap: (_) {},
        ),
      );

      // Should show all 4 levels plus curriculum
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Berachos'), findsOneWidget);
      expect(find.text('Perek 1'), findsOneWidget);
      expect(find.text('Mishna 1'), findsOneWidget);

      // Should have 4 chevron separators
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    });

    testWidgets('scrolls horizontally for long breadcrumbs', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: [
            'Very Long Seder Name That Might Overflow',
            'Very Long Masechta Name',
            'Perek With Long Name',
          ],
          onBreadcrumbTap: (_) {},
        ),
      );

      // Should have a horizontal scroll view
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
