/// R2 regression tests for the content-hierarchy screen layout/nav fixes:
///
/// Finding 4 — the root-chip separator chevron must point the SAME way as the
///   inner breadcrumb separators. In RTL both must be chevron_left; previously
///   the root-chip chevron was hardcoded chevron_right, disagreeing with the
///   inner separators in one RTL trail.
///
/// Finding 6 — the Android/system Back button must step up ONE hierarchy level
///   (matching the AppBar back-arrow), only popping the route when already at
///   the top level. Previously system Back popped the whole route, discarding
///   the entire drill path.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late ContentRepository mockRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
    mockRepo = _MockContentRepository();
  });

  const config = CurriculumHierarchyConfig(
    curriculumId: 'mishnayos',
    levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
    totalItems: 100,
  );

  // A single deep leaf so any drill depth has rows to render.
  final deepItems = <ContentItem>[
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berachos',
      level3: '1',
      level4: '1',
      displayNameHe: 'משנה ברכות א:א',
      displayNameEn: 'Mishnah Berakhot 1:1',
      sefariaRef: 'Mishnah Berakhot 1.1',
      sortOrder: 0,
      isLeaf: true,
    ),
  ];

  // Stub every drill level used across these tests with explicit matchers
  // (the existing screen tests use explicit matchers; we mirror that rather
  // than relying on any() fallbacks for the enum).
  void stubAllDrillLevels() {
    when(
      () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
    ).thenAnswer((_) async => config);
    for (final levels in const [
      (null, null, null, null),
      ('Seder Zeraim', null, null, null),
      ('Seder Zeraim', 'Berachos', null, null),
      ('Seder Zeraim', 'Berachos', '1', null),
    ]) {
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: levels.$1,
          level2: levels.$2,
          level3: levels.$3,
          level4: levels.$4,
        ),
      ).thenAnswer((_) async => deepItems);
    }
  }

  Widget host({
    required Locale locale,
    String? level1,
    String? level2,
    String? level3,
  }) {
    final emptyTree = ContentTree.fromCurricula({
      for (final c in CurriculumId.values) c: const [],
    });
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
        contentTreeProvider.overrideWith((ref) async => emptyTree),
        curriculumContentProvider.overrideWith(
          (ref, CurriculumId cid) async => const <ContentItem>[],
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ContentHierarchyScreen(
          curriculumId: 'mishnayos',
          level1: level1,
          level2: level2,
          level3: level3,
        ),
      ),
    );
  }

  group('R2 finding 4 — root-chip separator agrees with inner separators', () {
    testWidgets('RTL: root-chip + inner separators are ALL chevron_left', (
      tester,
    ) async {
      stubAllDrillLevels();

      // Drill two levels so there is one inner separator (between the two
      // breadcrumb crumbs) PLUS the root-chip separator. Both must agree.
      await tester.pumpWidget(
        host(
          locale: const Locale('he'),
          level1: 'Seder Zeraim',
          level2: 'Berachos',
        ),
      );
      await tester.pumpAndSettle();

      // In RTL every breadcrumb separator (root-chip + inner) must be
      // chevron_left, and NONE may be chevron_right.
      expect(
        find.byIcon(Icons.chevron_left),
        findsWidgets,
        reason: 'RTL trail separators must all point left',
      );
      // No separator chevron_right anywhere in the breadcrumb row. (The
      // content-list tiles render their own chevron_right trailing icon, so
      // scope the search to the breadcrumb row's Row of chips by excluding the
      // list — here we simply assert the root-chip separator is not a
      // chevron_right by checking the count of left chevrons is >= 2.)
      final leftCount = tester
          .widgetList<Icon>(find.byIcon(Icons.chevron_left))
          .length;
      expect(
        leftCount,
        greaterThanOrEqualTo(2),
        reason:
            'both the root-chip separator and the inner breadcrumb separator '
            'must be chevron_left in RTL (2 total)',
      );
    });

    testWidgets('LTR: root-chip + inner separators are chevron_right', (
      tester,
    ) async {
      stubAllDrillLevels();

      await tester.pumpWidget(
        host(
          locale: const Locale('en'),
          level1: 'Seder Zeraim',
          level2: 'Berachos',
        ),
      );
      await tester.pumpAndSettle();

      // No chevron_left anywhere in LTR.
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      // The root-chip separator + inner separator are chevron_right (>= 2);
      // content tiles may add more, which is fine.
      final rightCount = tester
          .widgetList<Icon>(find.byIcon(Icons.chevron_right))
          .length;
      expect(rightCount, greaterThanOrEqualTo(2));
    });
  });

  group(
    'R2 finding 6 — system Back steps up ONE level, not the whole path',
    () {
      testWidgets(
        'drilled 3 deep: system Back goes up one level (not all the way out)',
        (tester) async {
          stubAllDrillLevels();

          // Start drilled THREE levels deep via deep-link params.
          await tester.pumpWidget(
            host(
              locale: const Locale('en'),
              level1: 'Seder Zeraim',
              level2: 'Berachos',
              level3: '1',
            ),
          );
          await tester.pumpAndSettle();

          // Sanity: the screen is present and breadcrumb shows the deep trail.
          expect(find.byType(ContentHierarchyScreen), findsOneWidget);
          expect(find.byType(BreadcrumbNavigation), findsOneWidget);

          // Press the Android system Back button once.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          // The screen must STILL be mounted (route not popped) — we only
          // stepped up one level.
          expect(
            find.byType(ContentHierarchyScreen),
            findsOneWidget,
            reason:
                'system Back must step up one hierarchy level, not pop the '
                'entire route and discard the drill path',
          );
          // Still drilled in, so the breadcrumb (and AppBar back) remain.
          expect(find.byType(BreadcrumbNavigation), findsOneWidget);
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);

          // Step up two more times → now at root. Breadcrumb disappears.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          // At the root the breadcrumb (drill segments) is gone, but the screen
          // is still mounted — the route is only popped on the NEXT back press.
          expect(find.byType(ContentHierarchyScreen), findsOneWidget);
          expect(find.byType(BreadcrumbNavigation), findsNothing);
        },
      );
    },
  );
}
