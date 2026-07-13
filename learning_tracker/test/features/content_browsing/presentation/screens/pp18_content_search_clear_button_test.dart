/// Regression test for PP-18 — No clear (X) affordance in the content-search
/// field.
///
/// ROOT CAUSE: `ContentSearchScreen`'s `TextField` used `InputBorder.none`
/// and defined no `suffixIcon` / clear button. Once text was entered, the
/// only way to erase it was to backspace through every character.
///
/// FIX: `ContentSearchScreen` renders a suffix `IconButton` with
/// `Icons.clear` that calls `_searchController.clear()` and resets the
/// query, shown only when the field is non-empty (see the "PP-18 fix"
/// comment on `suffixIcon` in content_search_screen.dart).
///
/// AUD-t-content_browsing-01: this suite used to pump a hand-rolled
/// `TextField` clone that only "mirrored" the real screen's decoration
/// logic instead of the screen itself (TQ-8 — tautological test), so it
/// stayed green even if the real `suffixIcon` wiring broke. It now pumps
/// the real `ContentSearchScreen` and drives its real search field, so a
/// regression in the actual wiring fails this test.
@Tags(['unit', 'content_browsing', 'search', 'pp18'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Pumps the real [ContentSearchScreen] — not a hand-rolled clone — so
  /// this suite exercises the actual `suffixIcon` wiring it claims to
  /// protect (AUD-t-content_browsing-01).
  Future<void> pumpSearchScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid pulling in a real UserDatabase via the chazara-badge gate.
          anyActiveTrackHasChazaraProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContentSearchScreen(curriculumId: 'mishnayos'),
        ),
      ),
    );
    await tester.pump();
  }

  group('PP-18 — content search TextField clear icon', () {
    testWidgets('clear icon is absent when search field is empty', (
      tester,
    ) async {
      await pumpSearchScreen(tester);

      // With an empty field, no clear icon.
      expect(
        find.byIcon(Icons.clear),
        findsNothing,
        reason:
            'PP-18: clear button must not appear when search field is empty.',
      );
    });

    testWidgets('clear icon appears once text is entered', (tester) async {
      await pumpSearchScreen(tester);

      // Enter some text.
      await tester.enterText(find.byType(TextField), 'shabbos');
      // ContentSearchScreen debounces onChanged by 300ms before rebuilding
      // (see _onSearchChanged in content_search_screen.dart).
      await tester.pump(const Duration(milliseconds: 300));

      // With a non-empty field, the clear icon must appear.
      expect(
        find.byIcon(Icons.clear),
        findsOneWidget,
        reason:
            'PP-18 fix: a clear (X) icon must appear in the search field '
            'once the user has typed a query.',
      );
    });

    testWidgets('tapping clear icon empties the field and hides the icon', (
      tester,
    ) async {
      await pumpSearchScreen(tester);

      // Enter text and let the debounce settle.
      await tester.enterText(find.byType(TextField), 'mishnayot');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap the clear button.
      await tester.tap(find.byIcon(Icons.clear));
      // The clear button's onPressed also routes through _onSearchChanged,
      // which is debounced the same 300ms before the screen rebuilds.
      await tester.pump(const Duration(milliseconds: 300));

      // The field must now be empty and the clear icon gone.
      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.controller!.text, isEmpty);
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
