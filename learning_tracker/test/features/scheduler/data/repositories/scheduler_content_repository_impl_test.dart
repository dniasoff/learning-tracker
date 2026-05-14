// Tests for SchedulerContentRepositoryImpl — covers getLeafItems (lines 16-34).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';

void main() {
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
}
