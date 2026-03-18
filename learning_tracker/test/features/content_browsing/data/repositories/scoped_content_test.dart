import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';

/// Test-only subclass that allows injecting content directly.
class TestableContentRepository extends ContentRepositoryImpl {
  void seedContent(CurriculumId id, List<ContentItem> items) {
    // ignore: invalid_use_of_visible_for_testing_member
    // Access the parent's cache directly via the inherited getter.
    // Since the cache is private, we override getContentForCurriculum instead.
    _testContent[id] = items;
  }

  final _testContent = <CurriculumId, List<ContentItem>>{};

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    if (_testContent.containsKey(curriculumId)) {
      return _testContent[curriculumId]!;
    }
    return super.getContentForCurriculum(curriculumId);
  }
}

void main() {
  late TestableContentRepository repository;

  final testItems = [
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berachos',
      level3: 'Perek 1',
      level4: 'Mishna 1',
      displayNameHe: 'ברכות א:א',
      displayNameEn: 'Berachos 1:1',
      sefariaRef: 'Mishnah_Berakhot.1.1',
      sortOrder: 1,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berachos',
      level3: 'Perek 1',
      level4: 'Mishna 2',
      displayNameHe: 'ברכות א:ב',
      displayNameEn: 'Berachos 1:2',
      sefariaRef: 'Mishnah_Berakhot.1.2',
      sortOrder: 2,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Moed',
      level2: 'Shabbos',
      level3: 'Perek 1',
      level4: 'Mishna 1',
      displayNameHe: 'שבת א:א',
      displayNameEn: 'Shabbos 1:1',
      sefariaRef: 'Mishnah_Shabbat.1.1',
      sortOrder: 100,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Seder Nezikin',
      level2: 'Bava Kamma',
      level3: 'Perek 1',
      level4: 'Mishna 1',
      displayNameHe: 'בבא קמא א:א',
      displayNameEn: 'Bava Kamma 1:1',
      sefariaRef: 'Mishnah_Bava_Kamma.1.1',
      sortOrder: 200,
      isLeaf: true,
    ),
  ];

  setUp(() {
    repository = TestableContentRepository();
    repository.seedContent(CurriculumId.mishnayos, testItems);
  });

  group('getScopedContent', () {
    test('returns all items when scopeValues is empty', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: [],
      );
      expect(result, hasLength(4));
    });

    test('filters by level1 scope value', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Seder Zeraim'],
      );
      expect(result, hasLength(2));
      expect(result.every((i) => i.level1 == 'Seder Zeraim'), isTrue);
    });

    test('filters by multiple level1 scope values', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Seder Zeraim', 'Seder Moed'],
      );
      expect(result, hasLength(3));
    });

    test('filters by level2 scope value', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 2,
        scopeValues: ['Berachos'],
      );
      expect(result, hasLength(2));
      expect(result.every((i) => i.level2 == 'Berachos'), isTrue);
    });

    test('returns empty when scope matches nothing', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Seder Kodashim'],
      );
      expect(result, isEmpty);
    });

    test('filters by level3', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 3,
        scopeValues: ['Perek 1'],
      );
      // All test items have Perek 1
      expect(result, hasLength(4));
    });

    test('filters by level4', () async {
      final result = await repository.getScopedContent(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 4,
        scopeValues: ['Mishna 1'],
      );
      // 3 items have Mishna 1 (one per masechta)
      expect(result, hasLength(3));
    });
  });
}
