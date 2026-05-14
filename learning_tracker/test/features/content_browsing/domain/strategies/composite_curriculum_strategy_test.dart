// Tests for CompositeCurriculumStrategy — covers the default remap() path
// (lines 96-107) and the static _remapTanach path for nach items (lines 139-150).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';

void main() {
  const chumashItem = ContentItem(
    curriculumId: 'chumash',
    level1: 'Bereishit',
    level2: '1',
    level3: '1',
    displayNameHe: 'בראשית א:א',
    displayNameEn: 'Genesis 1:1',
    sefariaRef: 'Genesis 1:1',
    sortOrder: 0,
    isLeaf: true,
  );

  const nachItem = ContentItem(
    curriculumId: 'nach',
    level1: 'Nevi\'im',
    level2: 'Yehoshua',
    level3: '1',
    level4: '1',
    displayNameHe: 'יהושע א:א',
    displayNameEn: 'Joshua 1:1',
    sefariaRef: 'Joshua 1:1',
    sortOrder: 5,
    isLeaf: true,
  );

  // =========================================================================
  // Static registry — forKey / isComposite
  // =========================================================================

  group('CompositeCurriculumStrategy.forKey', () {
    test('returns strategy for tanach', () {
      final strategy = CompositeCurriculumStrategy.forKey('tanach');
      expect(strategy, isNotNull);
      expect(strategy!.compositeKey, 'tanach');
      expect(strategy.sources, containsAll(['chumash', 'nach']));
    });

    test('returns null for non-composite curriculum', () {
      expect(CompositeCurriculumStrategy.forKey('mishnayos'), isNull);
      expect(CompositeCurriculumStrategy.forKey('bavli'), isNull);
    });

    test('isComposite returns true for tanach', () {
      expect(CompositeCurriculumStrategy.isComposite('tanach'), isTrue);
    });

    test('isComposite returns false for other curricula', () {
      expect(CompositeCurriculumStrategy.isComposite('mishnayos'), isFalse);
    });
  });

  // =========================================================================
  // Default remap() — no remapSource provided
  // =========================================================================

  group('CompositeCurriculumStrategy.remap (default pass-through)', () {
    // Build a strategy without a custom remapSource so the default path runs.
    const strategy = CompositeCurriculumStrategy(
      compositeKey: 'composite_test',
      sources: ['src_a'],
    );

    test('copies all fields and updates curriculumId', () {
      final remapped = strategy.remap(
        item: chumashItem,
        source: 'src_a',
        offset: 0,
      );

      expect(remapped.curriculumId, 'composite_test');
      expect(remapped.level1, chumashItem.level1);
      expect(remapped.level2, chumashItem.level2);
      expect(remapped.level3, chumashItem.level3);
      expect(remapped.displayNameHe, chumashItem.displayNameHe);
      expect(remapped.displayNameEn, chumashItem.displayNameEn);
      expect(remapped.sefariaRef, chumashItem.sefariaRef);
      expect(remapped.isLeaf, chumashItem.isLeaf);
    });

    test('adds offset to sortOrder', () {
      final remapped = strategy.remap(
        item: chumashItem,
        source: 'src_a',
        offset: 100,
      );
      expect(remapped.sortOrder, chumashItem.sortOrder + 100);
    });
  });

  // =========================================================================
  // Tanach remap — _remapTanach for nach items (lines 139-150)
  // =========================================================================

  group('Tanach strategy remap', () {
    final tanach = CompositeCurriculumStrategy.forKey('tanach')!;

    test('remaps chumash item: level1=Torah, shifts other levels up', () {
      final remapped = tanach.remap(
        item: chumashItem,
        source: 'chumash',
        offset: 0,
      );

      expect(remapped.curriculumId, 'tanach');
      expect(remapped.level1, 'Torah');
      expect(remapped.level2, chumashItem.level1); // Bereishit
      expect(remapped.level3, chumashItem.level2); // chapter 1
      expect(remapped.level4, chumashItem.level3); // verse 1
    });

    test('remaps nach item: passes through all levels unchanged', () {
      final remapped = tanach.remap(item: nachItem, source: 'nach', offset: 10);

      expect(remapped.curriculumId, 'tanach');
      expect(remapped.level1, nachItem.level1); // Nevi'im
      expect(remapped.level2, nachItem.level2); // Yehoshua
      expect(remapped.level3, nachItem.level3); // 1
      expect(remapped.level4, nachItem.level4); // 1
      expect(remapped.sortOrder, nachItem.sortOrder + 10);
    });

    test('tanach preamble contains Torah container item', () {
      expect(tanach.preamble, hasLength(1));
      expect(tanach.preamble.first.level1, 'Torah');
      expect(tanach.preamble.first.isLeaf, isFalse);
    });
  });
}
