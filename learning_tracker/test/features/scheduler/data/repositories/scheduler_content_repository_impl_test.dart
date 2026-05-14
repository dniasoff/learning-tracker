// Tests for SchedulerContentRepositoryImpl — covers getLeafItems.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';

ContentItem makeItem({
  required String ref,
  required int sortOrder,
  String? level1,
  String? level2,
  String? level3,
  String? level4,
  bool isLeaf = true,
}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: level1 ?? 'L1',
    level2: level2,
    level3: level3,
    level4: level4,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: isLeaf,
  );
}

ContentItem _item(
  String ref, {
  required bool isLeaf,
  int sortOrder = 0,
  String level1 = 'Zeraim',
  String? level2,
}) => ContentItem(
  curriculumId: 'mishnayos',
  level1: level1,
  level2: level2,
  displayNameHe: '$ref-he',
  displayNameEn: '$ref-en',
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

void main() {
  group('SchedulerContentRepositoryImpl.getLeafItems', () {
    test('returns empty list when content is empty', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, isEmpty);
    });

    test('filters to only leaf items', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(ref: 'Container', sortOrder: 0, isLeaf: false),
          makeItem(ref: 'Leaf 1', sortOrder: 1, isLeaf: true),
          makeItem(ref: 'Leaf 2', sortOrder: 2, isLeaf: true),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, hasLength(2));
      expect(items.map((i) => i.sefariaRef), containsAll(['Leaf 1', 'Leaf 2']));
    });

    test('sorts items by sortOrder ascending', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(ref: 'C', sortOrder: 3),
          makeItem(ref: 'A', sortOrder: 1),
          makeItem(ref: 'B', sortOrder: 2),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items[0].sefariaRef, 'A');
      expect(items[1].sefariaRef, 'B');
      expect(items[2].sefariaRef, 'C');
    });

    test('maps all item fields correctly', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          const ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Zeraim',
            level2: 'Berakhot',
            level3: '1',
            level4: '1',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berakhot 1:1',
            sefariaRef: 'Mishnah Berakhot 1:1',
            sortOrder: 5,
            isLeaf: true,
          ),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      final item = items.first;

      expect(item.sefariaRef, 'Mishnah Berakhot 1:1');
      expect(item.sortOrder, 5);
      expect(item.level1, 'Zeraim');
      expect(item.level2, 'Berakhot');
      expect(item.level3, '1');
      expect(item.level4, '1');
    });

    test('passes the correct curriculumId to getContent', () async {
      CurriculumId? receivedId;
      final repo = SchedulerContentRepositoryImpl(
        getContent: (id) async {
          receivedId = id;
          return [];
        },
      );

      await repo.getLeafItems(CurriculumId.bavli);
      expect(receivedId, CurriculumId.bavli);
    });
  });

  group('SchedulerContentRepositoryImpl', () {
    test('getLeafItems returns only leaf items, sorted by sortOrder', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          _item('Berakhot', isLeaf: false, sortOrder: 0),
          _item('Berakhot 1:1', isLeaf: true, sortOrder: 2),
          _item('Berakhot 1:2', isLeaf: true, sortOrder: 1),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);

      expect(items, hasLength(2));
      expect(items[0].sefariaRef, 'Berakhot 1:2'); // lower sortOrder first
      expect(items[1].sefariaRef, 'Berakhot 1:1');
    });

    test('getLeafItems returns empty list when no leaf items exist', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          _item('Zeraim', isLeaf: false, sortOrder: 0),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, isEmpty);
    });

    test('getLeafItems maps content fields correctly', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          _item(
            'Berakhot 1:1',
            isLeaf: true,
            sortOrder: 5,
            level1: 'Zeraim',
            level2: 'Berakhot',
          ),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);

      expect(items, hasLength(1));
      final item = items.first;
      expect(item.sefariaRef, 'Berakhot 1:1');
      expect(item.sortOrder, 5);
      expect(item.level1, 'Zeraim');
      expect(item.level2, 'Berakhot');
    });

    test('getLeafItems passes curriculumId to getContent function', () async {
      CurriculumId? capturedId;
      final repo = SchedulerContentRepositoryImpl(
        getContent: (id) async {
          capturedId = id;
          return [];
        },
      );

      await repo.getLeafItems(CurriculumId.bavli);

      expect(capturedId, CurriculumId.bavli);
    });
  });
}
