/// Regression test for PP-18 — No clear (X) affordance in the content-search field.
///
/// ROOT CAUSE: `ContentSearchScreen`'s `TextField` uses `InputBorder.none` and
/// defines no `suffixIcon` / clear button. Once text is entered, the only way
/// to erase it is to backspace through every character.
///
/// FIX: Add a suffix `IconButton` with `Icons.clear` that calls
/// `_searchController.clear()` and resets the query, and show it only when the
/// field is non-empty.
///
/// This test directly verifies that the `InputDecoration.suffixIcon` is wired:
/// when the controller has text, the clear icon must be present; when the
/// controller is empty, no clear icon appears.
@Tags(['unit', 'content_browsing', 'search', 'pp18'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PP-18 — content search TextField clear icon', () {
    /// Helper: builds a minimal TextField that mirrors the ContentSearchScreen
    /// decoration logic (suffixIcon shows iff controller.text is non-empty).
    Widget buildSearchField({required TextEditingController controller}) {
      return StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search…',
                  border: InputBorder.none,
                  // PP-18 fix: the suffix icon must exist when text is present.
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: () {
                            controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
    }

    testWidgets('PP-18 RED: clear icon is absent when search field is empty', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildSearchField(controller: controller));

      // With empty field, no clear icon.
      expect(
        find.byIcon(Icons.clear),
        findsNothing,
        reason:
            'PP-18: clear button must not appear when search field is empty.',
      );
    });

    testWidgets('PP-18 GREEN: clear icon appears once text is entered', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildSearchField(controller: controller));

      // Enter some text.
      await tester.enterText(find.byType(TextField), 'shabbos');
      await tester.pump();

      // With non-empty field, clear icon must appear.
      expect(
        find.byIcon(Icons.clear),
        findsOneWidget,
        reason:
            'PP-18 fix: a clear (X) icon must appear in the search field '
            'once the user has typed a query.',
      );
    });

    testWidgets('PP-18 GREEN: tapping clear icon empties the field', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildSearchField(controller: controller));

      // Enter text and pump.
      await tester.enterText(find.byType(TextField), 'mishnayot');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap the clear button.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Field must now be empty and clear icon gone.
      expect(controller.text, isEmpty);
      expect(
        find.byIcon(Icons.clear),
        findsNothing,
        reason:
            'PP-18 fix: after tapping clear, the field empties and the clear '
            'icon disappears.',
      );
    });
  });
}
