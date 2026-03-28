import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/program_selection_step.dart';

void main() {
  group('ProgramSelectionStep', () {
    testWidgets('shows programs for Bavli', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgramSelectionStep(
              curriculumId: CurriculumId.bavli,
              onSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('Daf Yomi'), findsOneWidget);
      expect(find.text('Oraysa'), findsOneWidget);
      expect(find.text('Self-paced (no program)'), findsOneWidget);
    });

    testWidgets('shows programs for Mishna Berurah', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgramSelectionStep(
              curriculumId: CurriculumId.mishnaBerurah,
              onSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('Dirshu'), findsOneWidget);
      expect(find.text('Self-paced (no program)'), findsOneWidget);
    });

    testWidgets('selecting a program calls onSelected with id and name', (
      tester,
    ) async {
      int? selectedId;
      String? selectedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgramSelectionStep(
              curriculumId: CurriculumId.bavli,
              onSelected: (id, name) {
                selectedId = id;
                selectedName = name;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Daf Yomi'));
      expect(selectedId, 1);
      expect(selectedName, 'דף היומי');
    });

    testWidgets('self-paced calls onSelected with null', (tester) async {
      int? selectedId = 999;
      String? selectedName = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgramSelectionStep(
              curriculumId: CurriculumId.bavli,
              onSelected: (id, name) {
                selectedId = id;
                selectedName = name;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Self-paced (no program)'));
      expect(selectedId, isNull);
      expect(selectedName, isNull);
    });
  });
}
