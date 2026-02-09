import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/curriculum_indicator.dart';

void main() {
  group('CurriculumIndicator', () {
    testWidgets('displays indicator for mishna curriculum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'mishna'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(AppTheme.curriculumMishna));
    });

    testWidgets('displays indicator for bavli curriculum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'bavli'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(AppTheme.curriculumBavli));
    });

    testWidgets('displays indicator for yerushalmi curriculum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'yerushalmi'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(AppTheme.curriculumYerushalmi));
    });

    testWidgets('displays indicator for mishna_berurah curriculum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'mishna_berurah'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(AppTheme.curriculumMishnaBerurah));
    });

    testWidgets('displays indicator for chumash curriculum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'chumash'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(AppTheme.curriculumChumash));
    });

    testWidgets('displays label when provided', (WidgetTester tester) async {
      const label = 'Mishna';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(
              curriculumId: 'mishna',
              label: label,
            ),
          ),
        ),
      );

      expect(find.text(label), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('does not display label when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'mishna'),
          ),
        ),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('displays circle shape by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'mishna'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.shape, equals(BoxShape.circle));
    });

    testWidgets('displays square shape when specified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(
              curriculumId: 'mishna',
              shape: CurriculumIndicatorShape.square,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.shape, equals(BoxShape.rectangle));
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('displays bar shape when specified',
        (WidgetTester tester) async {
      const customSize = 24.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(
              curriculumId: 'mishna',
              size: customSize,
              shape: CurriculumIndicatorShape.bar,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));

      expect(container.constraints!.maxWidth, equals(customSize * 3));
      expect(container.constraints!.maxHeight, equals(customSize / 3));
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      const customSize = 32.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(
              curriculumId: 'mishna',
              size: customSize,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));

      expect(container.constraints!.maxWidth, equals(customSize));
      expect(container.constraints!.maxHeight, equals(customSize));
    });

    testWidgets('uses default size when not specified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CurriculumIndicator(curriculumId: 'mishna'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));

      expect(container.constraints!.maxWidth, equals(24.0));
      expect(container.constraints!.maxHeight, equals(24.0));
    });
  });
}
