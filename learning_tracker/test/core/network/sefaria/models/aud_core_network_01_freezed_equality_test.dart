// AUD-core-network-01: ContentItem/CurriculumHierarchyConfig/FetchResult
// converted to @freezed instead of hand-rolled or absent equality.
//
// Regression coverage for the two behavioral gaps named in the finding:
//  1. ContentItem's old hand-rolled `==` compared only curriculumId +
//     sefariaRef, so two items differing only in sortOrder/displayNameHe
//     compared equal. The generated `==` must compare every field.
//  2. CurriculumHierarchyConfig had no `==` at all (identity fallback) and
//     exposed a directly-mutable `levelLabels` list, so a caller mutating
//     the list obtained from one reader could corrupt the same cached
//     instance for every other reader.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

ContentItem _baseItem({int sortOrder = 1, String displayNameHe = 'א'}) =>
    ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berachos',
      level3: '1',
      level4: '1',
      displayNameHe: displayNameHe,
      displayNameEn: 'Berachos 1:1',
      sefariaRef: 'Mishnah Berachos 1.1',
      sortOrder: sortOrder,
      isLeaf: true,
    );

void main() {
  group('ContentItem equality (AUD-core-network-01)', () {
    test('two items with identical fields are ==', () {
      expect(_baseItem(), equals(_baseItem()));
    });

    test('items differing only in sortOrder are NOT ==', () {
      final a = _baseItem(sortOrder: 1);
      final b = _baseItem(sortOrder: 2);

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('items differing only in displayNameHe are NOT ==', () {
      final a = _baseItem(displayNameHe: 'א');
      final b = _baseItem(displayNameHe: 'ב');

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('copyWith produces a distinct value for a changed field', () {
      final a = _baseItem();
      final b = a.copyWith(sortOrder: 99);

      expect(a, isNot(equals(b)));
      expect(b.sortOrder, 99);
    });
  });

  group('CurriculumHierarchyConfig equality and immutability '
      '(AUD-core-network-01)', () {
    test('field-identical configs are == (previously fell back to '
        'identity)', () {
      // Deliberately NOT `const`: two separately-heap-allocated, non-
      // identical instances, so this only passes if `==` truly compares
      // fields rather than short-circuiting on `identical`/const-folding.
      final a = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: List.of(['Seder', 'Masechta', 'Perek', 'Mishna']),
        totalItems: 100,
      );
      final b = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: List.of(['Seder', 'Masechta', 'Perek', 'Mishna']),
        totalItems: 100,
      );

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('configs differing only in levelLabels are NOT ==', () {
      final a = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: List.of(['Seder', 'Masechta']),
        totalItems: 100,
      );
      final b = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: List.of(['Seder', 'Masechta', 'Perek']),
        totalItems: 100,
      );

      expect(a, isNot(equals(b)));
    });

    test('levelLabels cannot be mutated through the public API, even when '
        'constructed from a caller-owned mutable list — protects '
        'ContentRepositoryImpl._configCache, which hands the same cached '
        'instance to every reader', () {
      final mutableInput = <String>['Seder', 'Masechta'];
      final config = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: mutableInput,
        totalItems: 10,
      );

      expect(() => config.levelLabels.add('Perek'), throwsUnsupportedError);
      expect(() => config.levelLabels.removeAt(0), throwsUnsupportedError);
      expect(() => config.levelLabels[0] = 'x', throwsUnsupportedError);

      // Mutating the original caller-owned list must not corrupt the
      // config either way round — but the defining property under test
      // is that the reference exposed by the getter itself rejects
      // mutation, regardless of what was passed in.
      expect(config.levelLabels, ['Seder', 'Masechta']);
    });
  });

  group('FetchResult equality (AUD-core-network-01)', () {
    test('field-identical results are == (previously no == at all)', () {
      const config = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: ['Seder'],
        totalItems: 1,
      );
      final a = FetchResult(items: [_baseItem()], hierarchyConfig: config);
      final b = FetchResult(items: [_baseItem()], hierarchyConfig: config);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results differing in items are NOT ==', () {
      const config = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: ['Seder'],
        totalItems: 1,
      );
      final a = FetchResult(
        items: [_baseItem(sortOrder: 1)],
        hierarchyConfig: config,
      );
      final b = FetchResult(
        items: [_baseItem(sortOrder: 2)],
        hierarchyConfig: config,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
