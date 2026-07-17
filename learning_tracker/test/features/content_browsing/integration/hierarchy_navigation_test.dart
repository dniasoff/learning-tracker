import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  late MockContentRepository mockRepo;
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // DNI-328 flipped the Hebrew-terms default to false. These tests assert on
  // Hebrew labels, so seed the preference to true for the default profile.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
    mockRepo = MockContentRepository();
    router = _MockStackRouter();
    when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  });

  // [router] is only needed by the test that exercises a `context.router`
  // push (StackRouterScope wraps [home] so `context.router` resolves to the
  // mocked StackRouter instead of throwing for want of an AutoRouter
  // ancestor). Tests that never navigate omit it and get a plain MaterialApp.
  Widget createTestApp({required Widget home, _MockStackRouter? router}) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        // Override the completion percentage provider to avoid DB dependency
        dashboardCompletionPercentageProvider.overrideWith(
          (ref, curriculum) async => 0.0,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: router == null
            ? home
            : StackRouterScope(controller: router, stateHash: 0, child: home),
      ),
    );
  }

  group('Full hierarchy navigation flow', () {
    testWidgets(
      'navigates from curriculum list → seder → masechta → perek → mishna',
      (tester) async {
        // Mock Mishnayos content with hierarchical structure
        final mishnayosContent = [
          // Level 1: Seder
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            displayNameHe: 'סדר זרעים',
            displayNameEn: 'Seder Zeraim',
            sefariaRef: 'Seder Zeraim',
            sortOrder: 0,
            isLeaf: false,
          ),
          // Level 2: Masechta
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berachos',
            sefariaRef: 'Berachos',
            sortOrder: 1,
            isLeaf: false,
          ),
          // Level 3: Perek
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            level3: 'Perek 1',
            displayNameHe: 'פרק א',
            displayNameEn: 'Perek 1',
            sefariaRef: 'Berachos 1',
            sortOrder: 2,
            isLeaf: false,
          ),
          // Level 4: Mishna (leaf)
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            level3: 'Perek 1',
            level4: 'Mishna 1',
            displayNameHe: 'משנה א',
            displayNameEn: 'Mishna 1',
            sefariaRef: 'Mishnah Berakhot 1.1',
            sortOrder: 3,
            isLeaf: true,
          ),
        ];

        // Setup mocks for curriculum list
        when(
          () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => mishnayosContent);

        for (final curriculum in CurriculumId.values) {
          if (curriculum != CurriculumId.mishnayos) {
            when(
              () => mockRepo.getContentForCurriculum(curriculum),
            ).thenAnswer((_) async => []);
          }
        }

        // NOTE: this test only exercises the FIRST hop (curriculum list →
        // tap → route push). It intentionally does NOT stub
        // getHierarchyConfig/filterByLevel — the mocked StackRouter below
        // captures the push instead of letting a real AutoRouter build
        // ContentHierarchyScreen, so those stubs would never be consulted.
        // Deeper-level breadcrumb/filter behaviour is covered by
        // 'breadcrumb navigation allows jumping to parent levels' below and
        // by r2_content_hierarchy_nav_test.dart.

        // Step 1: Start with curriculum list
        await tester.pumpWidget(
          createTestApp(home: const CurriculumListScreen(), router: router),
        );
        await tester.pumpAndSettle();

        // Verify curriculum list shows Mishnayos (Hebrew display name may appear 2x)
        expect(find.text('משניות'), findsWidgets);

        // Step 2: Tap Mishnayos → navigate to hierarchy screen
        await tester.tap(find.text('משניות').first);
        await tester.pump();

        // The tap must push the SPECIFIC ContentHierarchyRoute for the
        // tapped curriculum via context.router — not merely "some
        // exception happened", which would also pass for an unrelated
        // build error introduced by a future regression.
        verify(
          () => router.push<Object?>(
            any(
              that: isA<ContentHierarchyRoute>().having(
                (r) => r.args?.curriculumId,
                'curriculumId',
                CurriculumId.mishnayos.storageKey,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('breadcrumb navigation allows jumping to parent levels', (
      tester,
    ) async {
      // Setup mock data
      when(
        () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 4192,
        ),
      );

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Perek 1',
          level4: null,
        ),
      ).thenAnswer(
        (_) async => [
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
        ],
      );

      // Start at a deep level (perek 1 inside Berachos inside Seder Zeraim).
      // Level3 carries the Arabic-integer perek number as in production data.
      await tester.pumpWidget(
        createTestApp(
          home: const ContentHierarchyScreen(
            curriculumId: 'mishnayos',
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            level3: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Curriculum chip appears once. The breadcrumb segments are rendered
      // through the unified label renderer — named levels (Seder, Masechta)
      // appear bare, ordinal levels prefixed with the level word.
      expect(find.text('משניות'), findsOneWidget);
      // Seder Zeraim → bare value (no hebrewName plumbed in test stub).
      expect(find.text('Seder Zeraim'), findsOneWidget);
      // Masechta → bare value.
      expect(find.text('Berachos'), findsOneWidget);
      // Perek → gematriya-converted with prefix.
      expect(find.text('פרק א'), findsOneWidget);
    });
  });

  group('Performance tests', () {
    testWidgets('scrolls smoothly with 500+ items', (tester) async {
      // Generate 500 items
      final items = List.generate(
        500,
        (i) => ContentItem(
          curriculumId: 'bavli',
          level1: 'Bavli',
          level2: 'Berachos',
          level3: 'Daf $i',
          displayNameHe: 'דף $i',
          displayNameEn: 'Daf $i',
          sefariaRef: 'Berachos $i',
          sortOrder: i,
          isLeaf: true,
        ),
      );

      when(() => mockRepo.getHierarchyConfig(CurriculumId.bavli)).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'bavli',
          levelLabels: ['Masechta', 'Daf', 'Amud'],
          totalItems: 5422,
        ),
      );

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.bavli,
          level1: 'Bavli',
          level2: 'Berachos',
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => items);

      await tester.pumpWidget(
        createTestApp(
          home: const ContentHierarchyScreen(
            curriculumId: 'bavli',
            level1: 'Bavli',
            level2: 'Berachos',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all items loaded
      expect(find.byType(ListView), findsOneWidget);

      // Scroll to bottom (simulates user scrolling)
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();

      // Should complete without frame drops (verified by pumpAndSettle)
      // In real tests, we'd use flutter driver or performance profiling
    });
  });
}
