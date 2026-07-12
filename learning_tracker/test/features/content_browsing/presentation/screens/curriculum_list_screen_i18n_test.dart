/// AUD-content_browsing-01 regression: CurriculumListScreen UI strings must
/// be localized.
///
/// Before the fix, CurriculumListScreen had zero AppLocalizations calls and
/// hard-coded English literals for: the AppBar title ("Browse Content"), the
/// search icon tooltip ("Search curricula") and decorative search-bar hint
/// ("Search curricula..."), the two section headers ("CURRICULA" /
/// "RECENT ACTIVITY"), the completion badges ("{pct} Done" / "New"), and the
/// Recent Activity empty-state copy ("Start learning to see activity here" /
/// "Your recent completions will appear below"). A Hebrew-locale user saw all
/// of these render in raw English on this core navigation screen.
///
/// This test was RED before the l10n keys were added and wired up.
@Tags(['content_browsing', 'i18n'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late _MockContentRepository mockRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockRepo = _MockContentRepository();
    for (final curriculum in CurriculumId.values) {
      when(
        () => mockRepo.getContentForCurriculum(curriculum),
      ).thenAnswer((_) async => <ContentItem>[]);
    }
  });

  // The body is a plain ListView(children: ...) inside a Sliver viewport —
  // only children near the visible viewport are actually built. With 9+
  // curriculum cards ahead of it, the Recent Activity section sits well
  // below the default test-surface fold, so any assertion that targets it
  // must scroll it into view first.
  Future<void> scrollToRecentActivity(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
  }

  Widget buildHost({
    Locale? locale,
    double Function(CurriculumId curriculum)? completionForCurriculum,
  }) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        dashboardCompletionPercentageProvider.overrideWith(
          (ref, curriculum) async =>
              completionForCurriculum?.call(curriculum) ?? 0.0,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const CurriculumListScreen(),
      ),
    );
  }

  group('CurriculumListScreen — AUD-content_browsing-01: UI strings must be '
      'localized, not hard-coded', () {
    testWidgets('Hebrew locale: AppBar title renders in Hebrew', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(locale: const Locale('he')));
      await tester.pumpAndSettle();

      expect(
        find.text('עיון בתוכן'),
        findsOneWidget,
        reason:
            'AUD-content_browsing-01: AppBar title must use l10n so '
            'Hebrew locale shows "עיון בתוכן" not the hard-coded English '
            '"Browse Content"',
      );
      expect(
        find.text('Browse Content'),
        findsNothing,
        reason: 'Hard-coded English must not leak in Hebrew locale',
      );
    });

    testWidgets(
      'Hebrew locale: search tooltip and search-bar hint render in Hebrew',
      (tester) async {
        await tester.pumpWidget(buildHost(locale: const Locale('he')));
        await tester.pumpAndSettle();

        expect(find.byTooltip('חיפוש תוכניות לימוד'), findsOneWidget);
        expect(find.byTooltip('Search curricula'), findsNothing);

        expect(find.text('חיפוש תוכניות לימוד...'), findsOneWidget);
        expect(find.text('Search curricula...'), findsNothing);
      },
    );

    testWidgets('Hebrew locale: section headers render in Hebrew', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(locale: const Locale('he')));
      await tester.pumpAndSettle();

      expect(
        find.text('תוכניות לימוד'),
        findsOneWidget,
        reason: 'AUD-content_browsing-01: "CURRICULA" header must localize',
      );
      expect(find.text('CURRICULA'), findsNothing);

      await scrollToRecentActivity(tester);

      expect(
        find.text('פעילות אחרונה'),
        findsOneWidget,
        reason:
            'AUD-content_browsing-01: "RECENT ACTIVITY" header must '
            'localize',
      );
      expect(find.text('RECENT ACTIVITY'), findsNothing);
    });

    testWidgets(
      'Hebrew locale: Recent Activity empty-state copy renders in Hebrew',
      (tester) async {
        await tester.pumpWidget(buildHost(locale: const Locale('he')));
        await tester.pumpAndSettle();
        await scrollToRecentActivity(tester);

        expect(find.text('התחל ללמוד כדי לראות פעילות כאן'), findsOneWidget);
        expect(find.text('Start learning to see activity here'), findsNothing);

        expect(find.text('ההשלמות האחרונות שלך יופיעו למטה'), findsOneWidget);
        expect(
          find.text('Your recent completions will appear below'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Hebrew locale: "New" badge renders in Hebrew for a curriculum with '
      'no completions',
      (tester) async {
        await tester.pumpWidget(buildHost(locale: const Locale('he')));
        await tester.pumpAndSettle();

        expect(find.text('חדש'), findsWidgets);
        expect(find.text('New'), findsNothing);
      },
    );

    testWidgets(
      'Hebrew locale: completion badge renders "X% הושלם" not "X% Done"',
      (tester) async {
        await tester.pumpWidget(
          buildHost(
            locale: const Locale('he'),
            completionForCurriculum: (curriculum) =>
                curriculum == CurriculumId.mishnayos ? 0.42 : 0.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('הושלם'), findsWidgets);
        expect(find.textContaining(' Done'), findsNothing);
      },
    );

    testWidgets(
      'English locale: UI strings still render in English after fix',
      (tester) async {
        await tester.pumpWidget(buildHost(locale: const Locale('en')));
        await tester.pumpAndSettle();

        expect(find.text('Browse Content'), findsOneWidget);
        expect(find.byTooltip('Search curricula'), findsOneWidget);
        expect(find.text('Search curricula...'), findsOneWidget);
        expect(find.text('CURRICULA'), findsOneWidget);
        expect(find.text('New'), findsWidgets);

        await scrollToRecentActivity(tester);

        expect(find.text('RECENT ACTIVITY'), findsOneWidget);
        expect(
          find.text('Start learning to see activity here'),
          findsOneWidget,
        );
        expect(
          find.text('Your recent completions will appear below'),
          findsOneWidget,
        );
      },
    );
  });
}
