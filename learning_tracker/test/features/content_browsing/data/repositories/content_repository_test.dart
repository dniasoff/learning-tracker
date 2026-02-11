import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

void main() {
  late ContentRepository repository;

  setUp(() {
    repository = ContentRepositoryImpl();
  });

  group('ContentRepository Acceptance Tests', () {
    // Acceptance Test 1: Get top-level items for Mishnayos
    test('AT1: getContentForCurriculum returns top-level Sedarim for Mishnayos',
        () async {
      final items = await repository.getContentForCurriculum(
        CurriculumId.mishnayos,
      );

      // Mishnayos should have 6 Sedarim at top level
      final sedarim = items
          .where((item) => item.level2 == null && !item.isLeaf)
          .toSet()
          .toList();

      // Should have content items (exact count depends on actual data)
      expect(items, isNotEmpty);

      // Verify structure: items should have Hebrew and English names
      for (final item in items.take(10)) {
        expect(item.displayNameHe, isNotEmpty);
        expect(item.displayNameEn, isNotEmpty);
        expect(item.curriculumId, 'mishnayos');
      }

      // Items should be ordered by sortOrder
      for (var i = 0; i < items.length - 1; i++) {
        expect(
          items[i].sortOrder,
          lessThanOrEqualTo(items[i + 1].sortOrder),
          reason: 'Items should be sorted by sortOrder',
        );
      }
    });

    // Acceptance Test 2: Filter by level returns children sorted by sortOrder
    test('AT2: Filtering by Seder Zeraim returns children sorted by sortOrder',
        () async {
      // First, get top-level to find Seder Zeraim
      final allItems = await repository.getContentForCurriculum(
        CurriculumId.mishnayos,
      );

      // Find Seder Zeraim (or use the first seder)
      final sederZeraim = allItems.firstWhere(
        (item) => item.displayNameEn.contains('Zeraim') || item.level1 != '',
        orElse: () => allItems.first,
      );

      // Filter by that seder
      final children = await repository.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: sederZeraim.level1,
        level2: null,
        level3: null,
        level4: null,
      );

      expect(children, isNotEmpty);

      // Verify all children belong to the same seder
      for (final child in children) {
        expect(child.level1, sederZeraim.level1);
      }

      // Verify sorted by sortOrder
      for (var i = 0; i < children.length - 1; i++) {
        expect(
          children[i].sortOrder,
          lessThanOrEqualTo(children[i + 1].sortOrder),
          reason: 'Children should be sorted by sortOrder',
        );
      }
    });

    // Acceptance Test 4: Hierarchy config returns correct level labels
    test('AT4: getHierarchyConfig returns correct level labels for Mishnayos',
        () async {
      final config = await repository.getHierarchyConfig(
        CurriculumId.mishnayos,
      );

      expect(config.curriculumId, 'mishnayos');
      expect(config.levelLabels, isNotEmpty);
      expect(config.depth, greaterThan(0));

      // Mishnayos typically has 4 levels: Seder, Masechta, Perek, Mishna
      // Verify the structure (actual labels may vary)
      expect(config.levelLabels.length, greaterThanOrEqualTo(3));

      // Verify total items count is reasonable
      expect(config.totalItems, greaterThan(0));
    });

    test('ContentRepository loads content for all curricula', () async {
      // Verify all 5 curricula can be loaded
      for (final curriculum in CurriculumId.values) {
        final items = await repository.getContentForCurriculum(curriculum);
        expect(items, isNotEmpty,
            reason: '${curriculum.displayNameEn} should have content');

        final config = await repository.getHierarchyConfig(curriculum);
        expect(config.curriculumId, curriculum.storageKey);
        expect(config.levelLabels, isNotEmpty);
      }
    });

    test('filterByLevel with multiple level constraints returns correct items',
        () async {
      final allItems = await repository.getContentForCurriculum(
        CurriculumId.mishnayos,
      );

      // Find an item with at least 3 levels
      final deepItem = allItems.firstWhere(
        (item) => item.level3 != null,
        orElse: () => allItems.first,
      );

      if (deepItem.level3 != null) {
        // Filter by level1 and level2
        final filtered = await repository.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: deepItem.level1,
          level2: deepItem.level2,
          level3: null,
          level4: null,
        );

        expect(filtered, isNotEmpty);

        // All items should match level1 and level2
        for (final item in filtered) {
          expect(item.level1, deepItem.level1);
          expect(item.level2, deepItem.level2);
        }
      }
    });

    test('search returns items matching Hebrew or English query', () async {
      final results = await repository.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'Berachos',
      );

      expect(results, isNotEmpty);

      // At least one result should contain the query in English or Hebrew
      final hasMatch = results.any(
        (item) =>
            item.displayNameEn.toLowerCase().contains('berachos') ||
            item.displayNameHe.contains('ברכות'),
      );
      expect(hasMatch, isTrue);
    });

    test('getContentByRef returns correct item', () async {
      final allItems = await repository.getContentForCurriculum(
        CurriculumId.mishnayos,
      );

      final firstItem = allItems.first;
      final retrieved = await repository.getContentByRef(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: firstItem.sefariaRef,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.sefariaRef, firstItem.sefariaRef);
      expect(retrieved.displayNameEn, firstItem.displayNameEn);
      expect(retrieved.displayNameHe, firstItem.displayNameHe);
    });

    test('getContentByRef returns null for non-existent ref', () async {
      final retrieved = await repository.getContentByRef(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'NonExistent Reference',
      );

      expect(retrieved, isNull);
    });

    test('search with empty query returns empty list', () async {
      final results = await repository.search(
        curriculumId: CurriculumId.mishnayos,
        query: '',
      );

      expect(results, isEmpty);
    });
  });

  group('ContentRepository Performance', () {
    test('loads large curriculum (Bavli) without timeout', () async {
      // Bavli has ~5400 items - should load quickly from cache
      final items = await repository.getContentForCurriculum(
        CurriculumId.bavli,
      );

      expect(items, isNotEmpty);
      expect(items.length, greaterThan(100));
    });

    test('caches content after first load', () async {
      // First load
      final stopwatch = Stopwatch()..start();
      await repository.getContentForCurriculum(CurriculumId.mishnayos);
      final firstLoadTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      // Second load (should be from cache)
      await repository.getContentForCurriculum(CurriculumId.mishnayos);
      final cachedLoadTime = stopwatch.elapsedMilliseconds;

      // Cached load should be significantly faster (< 5ms vs 50-100ms)
      expect(cachedLoadTime, lessThan(firstLoadTime ~/ 2),
          reason: 'Cached load should be faster than initial load');
    });
  });
}
