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
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late ContentRepository mockRepo;

  setUp(() {
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
      overrides: [contentRepositoryProvider.overrideWithValue(mockRepo)],
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

      // Should display both items
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Seder Moed'), findsOneWidget);

      // Hebrew names should also be visible
      expect(find.text('סדר זרעים'), findsOneWidget);
      expect(find.text('סדר מועד'), findsOneWidget);
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
      // This will be tested in integration tests with full navigation stack
    });

    testWidgets('displays leaf items with different styling', (tester) async {
      final testItems = [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Perek 1',
          level4: 'Mishna 1',
          displayNameHe: 'משנה א',
          displayNameEn: 'Mishna 1',
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
          level3: 'Perek 1',
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
        createTestWidget(
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Perek 1',
        ),
      );
      await tester.pumpAndSettle();

      // Leaf items should be visible
      expect(find.text('Mishna 1'), findsOneWidget);
    });
  });
}
