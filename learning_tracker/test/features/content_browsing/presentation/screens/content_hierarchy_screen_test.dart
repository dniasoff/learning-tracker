import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late ContentRepository mockRepo;

  // DNI-328 flipped the Hebrew-terms default to false. These tests assert on
  // Hebrew labels, so seed the preference to true for the default profile.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
    mockRepo = MockContentRepository();
  });

  Widget createTestWidget({
    String? curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        // Stub completionCountProvider to return 0 for all items
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
      ],
      child: MaterialApp(
        home: ContentHierarchyScreen(
          curriculumId: curriculumId ?? 'mishnayos',
          level1: level1,
          level2: level2,
          level3: level3,
          level4: level4,
        ),
      ),
    );
  }

  group('ContentHierarchyScreen', () {
    testWidgets('displays top-level items when no level filters', (
      tester,
    ) async {
      final testItems = [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          displayNameHe: 'סדר זרעים',
          displayNameEn: 'Seder Zeraim',
          sefariaRef: 'Seder Zeraim',
          sortOrder: 0,
          isLeaf: false,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Moed',
          displayNameHe: 'סדר מועד',
          displayNameEn: 'Seder Moed',
          sefariaRef: 'Seder Moed',
          sortOrder: 1,
          isLeaf: false,
        ),
      ];

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => testItems);

      when(
        () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 100,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Hebrew titles are shown by default. The unified label renderer
      // strips the "סדר " structural prefix because the level word is
      // implicit at this drill-down depth.
      expect(find.text('זרעים'), findsOneWidget);
      expect(find.text('מועד'), findsOneWidget);
      // English transliterations are hidden in default Hebrew-only mode.
      expect(find.text('Seder Zeraim'), findsNothing);
      expect(find.text('Seder Moed'), findsNothing);
    });

    testWidgets('shows breadcrumb navigation', (tester) async {
      final testItems = [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berachos',
          sefariaRef: 'Berachos',
          sortOrder: 0,
          isLeaf: false,
        ),
      ];

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => testItems);

      when(
        () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 100,
        ),
      );

      await tester.pumpWidget(createTestWidget(level1: 'Seder Zeraim'));
      await tester.pumpAndSettle();

      // Should show breadcrumb (the exact widget will be tested separately)
      expect(find.byType(BreadcrumbNavigation), findsOneWidget);
    });

    testWidgets('navigates back to previous level on back button', (
      tester,
    ) async {
      // Items shown at level1 depth (Seder Zeraim selected)
      final level1Items = [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berachos',
          sefariaRef: 'Berachos',
          sortOrder: 0,
          isLeaf: false,
        ),
      ];

      // Items shown at root level (no filters)
      final rootItems = [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          displayNameHe: 'סדר זרעים',
          displayNameEn: 'Seder Zeraim',
          sefariaRef: 'Seder Zeraim',
          sortOrder: 0,
          isLeaf: false,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Moed',
          displayNameHe: 'סדר מועד',
          displayNameEn: 'Seder Moed',
          sefariaRef: 'Seder Moed',
          sortOrder: 1,
          isLeaf: false,
        ),
      ];

      when(
        () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 100,
        ),
      );

      // Mock for level1='Seder Zeraim' (initial view)
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => level1Items);

      // Mock for root level (after pressing back)
      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: null,
          level2: null,
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => rootItems);

      // Start at level1 depth
      await tester.pumpWidget(createTestWidget(level1: 'Seder Zeraim'));
      await tester.pumpAndSettle();

      // Verify we see the level1-filtered content (Hebrew title in default mode)
      expect(find.text('ברכות'), findsOneWidget);
      expect(find.text('Seder Moed'), findsNothing);

      // Back button should be visible when navigation stack is non-empty
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap the back button to navigate up
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Now we should see root-level items by their Hebrew titles
      // (structural prefix stripped by the unified label renderer).
      expect(find.text('זרעים'), findsOneWidget);
      expect(find.text('מועד'), findsOneWidget);

      // Back button is always present in the AppBar; at root level it
      // delegates to context.router.maybePop() instead of navigating up.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays browse-leaf items at max browse depth', (
      tester,
    ) async {
      // Mishnayos browse caps one level above leaf (Perek, not Mishna)
      // because drilling into individual mishnayos is too tedious for
      // browsing. At masechta depth the screen should render Perek rows
      // composed via gematriya: "פרק א".
      final testItems = [
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

      when(
        () => mockRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: null,
          level4: null,
        ),
      ).thenAnswer((_) async => testItems);

      when(
        () => mockRepo.getHierarchyConfig(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 100,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(level1: 'Seder Zeraim', level2: 'Berachos'),
      );
      await tester.pumpAndSettle();

      // Perek row composed via renderer: "פרק" + gematriya("1") = "פרק א".
      expect(find.text('פרק א'), findsOneWidget);
    });
  });
}
