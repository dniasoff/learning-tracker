/// Tests for [SchedulerContentItem] and [SchedulerContentRepositoryImpl].
///
/// Covers:
///  - [SchedulerContentItem.coarseUnitKey] for all hierarchy depth scenarios
///  - [SchedulerContentRepositoryImpl.getLeafItems] filtering and sorting
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';

void main() {
  // ─── SchedulerContentItem.coarseUnitKey ──────────────────────────────────

  group('SchedulerContentItem.coarseUnitKey', () {
    test('returns level1|level2|level3 for 4-level item (mishnayos style)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Berakhot.1.1',
        sortOrder: 1,
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
      );
      expect(item.coarseUnitKey, 'Zeraim|Berakhot|1');
    });

    test('returns level1|level2 for 3-level item (chumash style)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Genesis.1.1',
        sortOrder: 1,
        level1: 'Genesis',
        level2: '1',
        level3: '1',
        level4: null,
      );
      expect(item.coarseUnitKey, 'Genesis|1');
    });

    test('returns level1 for 2-level item', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Bavli.2a',
        sortOrder: 1,
        level1: 'Berakhot',
        level2: '2a',
        level3: null,
        level4: null,
      );
      expect(item.coarseUnitKey, 'Berakhot');
    });

    test('returns null for single-level item (no parent)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'SomeBook.1',
        sortOrder: 1,
        level1: null,
        level2: null,
        level3: null,
        level4: null,
      );
      expect(item.coarseUnitKey, isNull);
    });

    test('returns null when all level fields are null', () {
      const item = SchedulerContentItem(sefariaRef: 'ref-1', sortOrder: 0);
      expect(item.coarseUnitKey, isNull);
    });
  });

  // ─── SchedulerContentRepositoryImpl ──────────────────────────────────────

  group('SchedulerContentRepositoryImpl.getLeafItems', () {
    /// Helper to build a [ContentItem] for testing.
    ContentItem makeItem({
      required String sefariaRef,
      required bool isLeaf,
      required int sortOrder,
      String level1 = 'Zeraim',
      String? level2,
      String? level3,
      String? level4,
    }) {
      return ContentItem(
        sefariaRef: sefariaRef,
        displayNameEn: sefariaRef,
        displayNameHe: sefariaRef,
        sortOrder: sortOrder,
        curriculumId: CurriculumId.mishnayos.storageKey,
        isLeaf: isLeaf,
        level1: level1,
        level2: level2,
        level3: level3,
        level4: level4,
      );
    }

    test('filters out non-leaf items and returns only leaves', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(sefariaRef: 'container', isLeaf: false, sortOrder: 1),
          makeItem(sefariaRef: 'leaf-1', isLeaf: true, sortOrder: 2),
          makeItem(sefariaRef: 'leaf-2', isLeaf: true, sortOrder: 3),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, hasLength(2));
      expect(items.map((i) => i.sefariaRef).toList(), ['leaf-1', 'leaf-2']);
    });

    test('sorts leaf items by sortOrder ascending', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(sefariaRef: 'leaf-3', isLeaf: true, sortOrder: 3),
          makeItem(sefariaRef: 'leaf-1', isLeaf: true, sortOrder: 1),
          makeItem(sefariaRef: 'leaf-2', isLeaf: true, sortOrder: 2),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items.map((i) => i.sefariaRef).toList(), [
        'leaf-1',
        'leaf-2',
        'leaf-3',
      ]);
    });

    test('returns empty list when content has no leaf items', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(sefariaRef: 'container-only', isLeaf: false, sortOrder: 1),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, isEmpty);
    });

    test('returns empty list when content is empty', () async {
      final repo = SchedulerContentRepositoryImpl(getContent: (_) async => []);

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, isEmpty);
    });

    test('passes level fields through to SchedulerContentItem', () async {
      final repo = SchedulerContentRepositoryImpl(
        getContent: (_) async => [
          makeItem(
            sefariaRef: 'Berakhot.1.1',
            isLeaf: true,
            sortOrder: 1,
            level1: 'Zeraim',
            level2: 'Berakhot',
            level3: '1',
            level4: '1',
          ),
        ],
      );

      final items = await repo.getLeafItems(CurriculumId.mishnayos);
      expect(items, hasLength(1));
      expect(items.first.level1, 'Zeraim');
      expect(items.first.level2, 'Berakhot');
      expect(items.first.level3, '1');
      expect(items.first.level4, '1');
    });
  });
}
