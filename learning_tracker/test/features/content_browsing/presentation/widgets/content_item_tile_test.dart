import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';

void main() {
  Widget createTestWidget({
    required ContentItem item,
    required VoidCallback onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ContentItemTile(
          item: item,
          curriculum: CurriculumId.mishnayos,
          onTap: onTap,
        ),
      ),
    );
  }

  group('ContentItemTile', () {
    testWidgets('displays Hebrew name as title', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));

      // Hebrew name should be the title
      expect(find.text('סדר זרעים'), findsOneWidget);

      // Verify RTL directionality for Hebrew
      final hebrewText = tester.widget<Text>(find.text('סדר זרעים'));
      expect(hebrewText.textDirection, TextDirection.rtl);
      expect(hebrewText.textAlign, TextAlign.right);
    });

    testWidgets('displays English name as subtitle', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));

      // English name should be the subtitle
      expect(find.text('Seder Zeraim'), findsOneWidget);
    });

    testWidgets('shows folder icon for container items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets('shows unchecked icon for leaf items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: 'Perek 1',
        level4: 'Mishna 1',
        displayNameHe: 'משנה א',
        displayNameEn: 'Mishna 1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 0,
        isLeaf: true,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));

      // Leaf items show completion status icon (unchecked by default)
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('shows chevron for container items', (tester) async {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(createTestWidget(item: item, onTap: () {}));

      // Container items show chevron for drill-down
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );

      await tester.pumpWidget(
        createTestWidget(item: item, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });
  });

  group('StageCompletionIndicators', () {
    testWidgets('displays completion icons for each stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StageCompletionIndicators(
              stages: {
                1: true, // Complete
                2: false, // Incomplete
                3: true, // Complete
              },
            ),
          ),
        ),
      );

      // Should show 3 icons total
      expect(find.byType(Icon), findsNWidgets(3));

      // 2 should be check_circle (complete)
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

      // 1 should be circle_outlined (incomplete)
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });

  group('AggregateCompletionIndicator', () {
    testWidgets('displays percentage text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 75.5)),
        ),
      );

      // Should show rounded percentage
      expect(find.text('76%'), findsOneWidget);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 50)),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 0.5); // 50% = 0.5
    });

    testWidgets('handles 0% completion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 0)),
        ),
      );

      expect(find.text('0%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 0.0);
    });

    testWidgets('handles 100% completion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AggregateCompletionIndicator(percentage: 100)),
        ),
      );

      expect(find.text('100%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 1.0);
    });
  });
}
