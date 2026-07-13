/// Tests for the filtering, search, and lookup logic in [ContentRepositoryImpl].
///
/// [ContentRepositoryImpl] loads content from bundled JSON assets via
/// [rootBundle]. Since those assets are not present in test environments, this
/// file exercises the business-logic methods indirectly through a test subclass
/// that pre-populates the in-memory content cache, bypassing asset loading.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';

/// A test-only subclass of [ContentRepositoryImpl] that returns a fixed list
/// of [ContentItem]s instead of loading from bundled JSON assets.
class _FakeContentRepository extends ContentRepositoryImpl {
  _FakeContentRepository(this._fakeItems);

  final List<ContentItem> _fakeItems;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    return _fakeItems;
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    return CurriculumHierarchyConfig(
      curriculumId: curriculumId.storageKey,
      levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
      totalItems: _fakeItems.where((i) => i.isLeaf).length,
    );
  }
}

// ── Fixture helpers ──────────────────────────────────────────────────────────

ContentItem _item({
  required String ref,
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  bool isLeaf = true,
  int sortOrder = 0,
  String curriculum = 'mishnayos',
  String? displayNameHe,
  String? displayNameEn,
}) => ContentItem(
  curriculumId: curriculum,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: displayNameHe ?? '$ref-he',
  displayNameEn: displayNameEn ?? ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

final _fixtureItems = [
  _item(
    ref: 'Zeraim',
    level1: 'Zeraim',
    isLeaf: false,
    sortOrder: 0,
    displayNameHe: 'זרעים',
    displayNameEn: 'Zeraim',
  ),
  _item(
    ref: 'Berakhot',
    level1: 'Zeraim',
    level2: 'Berakhot',
    isLeaf: false,
    sortOrder: 0,
    displayNameHe: 'ברכות',
    displayNameEn: 'Berakhot',
  ),
  _item(
    ref: 'Berakhot 1',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: '1',
    isLeaf: false,
    sortOrder: 0,
    displayNameHe: 'פרק א׳',
    displayNameEn: 'Chapter 1',
  ),
  _item(
    ref: 'Berakhot 1:1',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: '1',
    level4: '1',
    isLeaf: true,
    sortOrder: 0,
    displayNameHe: 'ברכות א׳:א׳',
    displayNameEn: 'Berakhot 1:1',
  ),
  _item(
    ref: 'Berakhot 1:2',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: '1',
    level4: '2',
    isLeaf: true,
    sortOrder: 1,
    displayNameHe: 'ברכות א׳:ב׳',
    displayNameEn: 'Berakhot 1:2',
  ),
  _item(
    ref: 'Moed',
    level1: 'Moed',
    isLeaf: false,
    sortOrder: 1,
    displayNameHe: 'מועד',
    displayNameEn: 'Moed',
  ),
  _item(
    ref: 'Shabbat 1:1',
    level1: 'Moed',
    level2: 'Shabbat',
    level3: '1',
    level4: '1',
    isLeaf: true,
    sortOrder: 100,
    displayNameHe: 'שבת',
    displayNameEn: 'Shabbat 1:1',
  ),
];

void main() {
  late _FakeContentRepository repo;

  setUp(() {
    repo = _FakeContentRepository(_fixtureItems);
  });

  group('ContentRepositoryImpl.filterByLevel', () {
    test('filters by level1 only', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Zeraim',
      );

      expect(result.every((i) => i.level1 == 'Zeraim'), isTrue);
      expect(result.any((i) => i.level1 == 'Moed'), isFalse);
    });

    test('filters by level1 and level2', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Zeraim',
        level2: 'Berakhot',
      );

      expect(result.every((i) => i.level2 == 'Berakhot'), isTrue);
    });

    test('filters by level1, level2, and level3', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
      );

      expect(result.every((i) => i.level3 == '1'), isTrue);
    });

    test('returns empty when no items match the filter', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Nashim', // doesn't exist
      );

      expect(result, isEmpty);
    });

    test('returns all items when no filter is applied', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
      );

      expect(result, hasLength(_fixtureItems.length));
    });
  });

  group('ContentRepositoryImpl.getScopedContent', () {
    test('returns all items when scopeValues is empty', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: [],
      );

      expect(result, hasLength(_fixtureItems.length));
    });

    test('filters by level1 scope values', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Zeraim'],
      );

      expect(result.every((i) => i.level1 == 'Zeraim'), isTrue);
    });

    test('filters by level2 scope values', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 2,
        scopeValues: ['Berakhot'],
      );

      expect(result.every((i) => i.level2 == 'Berakhot'), isTrue);
    });

    test('returns items matching any of multiple scope values', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Zeraim', 'Moed'],
      );

      final level1s = result.map((i) => i.level1).toSet();
      expect(level1s, containsAll(['Zeraim', 'Moed']));
    });

    test('returns empty when scope value does not match any item', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Nonexistent'],
      );

      expect(result, isEmpty);
    });

    test('level 4 scoping works', () async {
      final result = await repo.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 4,
        scopeValues: ['1'],
      );

      // Items with level4=='1': Berakhot 1:1 and Shabbat 1:1
      expect(result.every((i) => i.level4 == '1'), isTrue);
      expect(result, isNotEmpty);
    });
  });

  group('ContentRepositoryImpl.search', () {
    test('returns empty list for empty query', () async {
      final result = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: '',
      );

      expect(result, isEmpty);
    });

    test('matches by rendered (Ashkenazi) leaf-segment name', () async {
      // Run-6: search also matches the rendered leaf-segment name, so the
      // Ashkenazi transliteration the UI actually displays ('Berakhos' for
      // Mishnayos's Zeraim > Berakhot) resolves even though it differs from
      // the raw displayNameEn ('Berakhot').
      final result = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'Berakhos',
      );

      expect(result.any((i) => i.sefariaRef == 'Berakhot'), isTrue);
    });

    test('also matches raw (un-transliterated) displayNameEn', () async {
      // AUD-t-content_browsing-02: a query in the Sephardic/standard
      // spelling ('Berakhot') must resolve too, since that is the raw
      // displayNameEn shipped in the bundled data and some users type it
      // even though the UI renders the Ashkenazi form ('Berakhos').
      final result = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'Berakhot',
      );

      expect(result.any((i) => i.sefariaRef == 'Berakhot'), isTrue);
    });

    test('search is case-insensitive for English', () async {
      final upper = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'BERAKHOT',
      );
      final lower = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'berakhot',
      );

      expect(
        upper.map((i) => i.sefariaRef).toList(),
        equals(lower.map((i) => i.sefariaRef).toList()),
      );
    });

    test('returns empty for query with no matches', () async {
      final result = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'zzznomatch',
      );

      expect(result, isEmpty);
    });

    test('second call reuses stripped-Hebrew cache (no error)', () async {
      // Calling search twice exercises the cache-reuse branch.
      await repo.search(curriculumId: CurriculumId.mishnayos, query: 'b');
      final second = await repo.search(
        curriculumId: CurriculumId.mishnayos,
        query: 'b',
      );
      expect(second, isNotEmpty);
    });
  });

  group('ContentRepositoryImpl.getContentByRef', () {
    test('returns item when ref exists', () async {
      final item = await repo.getContentByRef(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Berakhot 1:1',
      );

      expect(item, isNotNull);
      expect(item!.sefariaRef, 'Berakhot 1:1');
    });

    test('returns null when ref does not exist', () async {
      final item = await repo.getContentByRef(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'NonExistentRef',
      );

      expect(item, isNull);
    });
  });

  group('ContentRepositoryImpl.getHierarchyConfig', () {
    test('returns config from overridden method', () async {
      final config = await repo.getHierarchyConfig(CurriculumId.mishnayos);

      expect(config.curriculumId, 'mishnayos');
      expect(config.levelLabels, isNotEmpty);
    });
  });
}
