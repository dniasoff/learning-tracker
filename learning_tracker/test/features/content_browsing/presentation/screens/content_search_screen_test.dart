import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Override that keeps useHebrewTermsProvider always-false (English terms),
/// so the label passed to searchFieldHint is the English curriculum name.
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContentSearchScreen', () {
    testWidgets('renders without error', (tester) async {
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

      expect(find.byType(Scaffold), findsOneWidget);
    });

    // ── R4-4 Hebrew-locale regression test ───────────────────────────────────

    testWidgets('R4-4: Hebrew locale — search hint shows חיפוש, not "Search "', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
            anyActiveTrackHasChazaraProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            locale: Locale('he'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ContentSearchScreen(curriculumId: 'mishnayos'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // With Hebrew locale and English terms (useHebrewTermsProvider=false),
      // searchFieldHint returns "חיפוש [U+2066]Mishnayos[U+2069]…".
      // The curriculum-name placeholder is wrapped in U+2066...U+2069 LTR-isolate
      // marks; use Dart escape sequences (\u2066 / \u2069) in the string literal
      // to avoid the text_direction_code_point_in_literal analyzer warning.
      expect(
        find.text('חיפוש \u2066Mishnayos\u2069…'),
        findsOneWidget,
        reason:
            'R4-4: searchFieldHint in he locale must render the Hebrew prefix '
            'with U+2066...U+2069 isolates around the label, '
            'not the English "Search Mishnayos..."',
      );
      // The bare English "Search " prefix must be absent.
      expect(
        find.textContaining('Search '),
        findsNothing,
        reason:
            'R4-4: hardcoded English "Search " prefix must be absent in he locale',
      );
    });
  });
}
