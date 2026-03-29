import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/presentation/widgets/curriculum_picker_step.dart';

void main() {
  group('CurriculumPickerStep', () {
    testWidgets('displays all 9 curricula (scrollable)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CurriculumPickerStep(onSelected: (_) {})),
        ),
      );

      // Each curriculum appears with Hebrew name (may appear twice — title + subtitle)
      for (final curriculum in CurriculumId.values) {
        await tester.scrollUntilVisible(
          find.text(curriculum.displayNameHe).first,
          50,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(curriculum.displayNameHe), findsWidgets);
      }
    });

    testWidgets('shows onboarding header when isOnboarding is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumPickerStep(onSelected: (_) {}, isOnboarding: true),
          ),
        ),
      );

      expect(find.text('What would you like to learn?'), findsOneWidget);
    });

    testWidgets('shows default header when isOnboarding is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CurriculumPickerStep(onSelected: (_) {})),
        ),
      );

      expect(find.text('Select a Curriculum'), findsOneWidget);
    });

    testWidgets('tapping a curriculum calls onSelected', (tester) async {
      CurriculumId? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumPickerStep(onSelected: (c) => selected = c),
          ),
        ),
      );

      // Tap the first occurrence of the Hebrew name
      await tester.tap(find.text(CurriculumId.bavli.displayNameHe).first);
      expect(selected, CurriculumId.bavli);
    });
  });
}
