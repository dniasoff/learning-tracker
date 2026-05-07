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
    testWidgets('renders only the navigation stack — curriculum is shown by '
        'the adjacent chip, not duplicated here', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos'],
          onBreadcrumbTap: (_) {},
        ),
      );

      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Berachos'), findsOneWidget);
      // Curriculum name should NOT be repeated in the breadcrumb itself.
      expect(find.text('משניות'), findsNothing);
      // One separator between two stack items.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('makes previous levels clickable', (tester) async {
      var tappedLevel = -1;

      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos', 'Perek 1'],
          onBreadcrumbTap: (level) => tappedLevel = level,
        ),
      );

      await tester.tap(find.text('Seder Zeraim'));
      expect(tappedLevel, 0);

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

      final currentLevelFinder = find.text('Berachos');
      expect(currentLevelFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(currentLevelFinder);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('renders nothing for an empty navigation stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(navigationStack: [], onBreadcrumbTap: (_) {}),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('משניות'), findsNothing);
    });

    testWidgets('handles maximum depth (4 levels) with 3 separators between '
        'them', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          navigationStack: ['Seder Zeraim', 'Berachos', 'Perek 1', 'Mishna 1'],
          onBreadcrumbTap: (_) {},
        ),
      );

      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Berachos'), findsOneWidget);
      expect(find.text('Perek 1'), findsOneWidget);
      expect(find.text('Mishna 1'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
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

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
