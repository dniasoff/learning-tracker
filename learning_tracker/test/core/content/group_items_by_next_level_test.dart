// Regression coverage for groupItemsByNextLevel's depth-to-level mapping.
//
// AUD-core-content-05: content_grouping.dart carried two near-identical
// level-value accessors — a private 0-indexed `_levelValueAt` used only by
// groupItemsByNextLevel, and a public 1-indexed `levelValueAt` used
// everywhere else. Consolidating them onto the single public accessor is an
// off-by-one hazard: groupItemsByNextLevel's `currentDepth` is 0-indexed, so
// the call site must translate to the 1-indexed level (`currentDepth + 1`)
// when routing through the public accessor. These tests pin the correct
// (level1..level4) grouping at every depth so that hazard is caught here
// rather than by users seeing the wrong hierarchy level.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

ContentItem _item({
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required String ref,
  required bool isLeaf,
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: 'bavli',
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: '',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

void main() {
  // Bavli's level structure is Masechta(1) > Daf(2) > Amud(3),
  // so this fixture exercises each groupItemsByNextLevel depth (0-2).
  final items = [
    _item(
      level1: 'Berakhot',
      level2: '2',
      level3: 'a',
      ref: 'Berakhot 2a',
      isLeaf: true,
      sortOrder: 1,
    ),
    _item(
      level1: 'Berakhot',
      level2: '2',
      level3: 'b',
      ref: 'Berakhot 2b',
      isLeaf: true,
      sortOrder: 2,
    ),
    _item(
      level1: 'Berakhot',
      level2: '3',
      level3: 'a',
      ref: 'Berakhot 3a',
      isLeaf: true,
      sortOrder: 3,
    ),
    _item(
      level1: 'Shabbos',
      level2: '2',
      level3: 'a',
      ref: 'Shabbos 2a',
      isLeaf: true,
      sortOrder: 4,
    ),
    _item(
      level1: 'Yoma',
      level2: '2',
      level3: 'a',
      ref: 'Yoma 2a',
      isLeaf: true,
      sortOrder: 5,
    ),
  ];

  group('groupItemsByNextLevel depth-to-level mapping', () {
    test('depth 0 groups by level1 (Masechta)', () {
      final result = groupItemsByNextLevel(
        items: items,
        currentDepth: 0,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level1).toSet(), {
        'Berakhot',
        'Shabbos',
        'Yoma',
      });
      expect(result, hasLength(3));
    });

    test('depth 1 groups by level2 (Daf) within a Masechta', () {
      final berakhotItems = items.where((i) => i.level1 == 'Berakhot').toList();
      final result = groupItemsByNextLevel(
        items: berakhotItems,
        currentDepth: 1,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level2).toSet(), {'2', '3'});
      expect(result, hasLength(2));
    });

    test('depth 2 groups by level3 (Amud) within a Daf', () {
      final daf2Items = items
          .where((i) => i.level1 == 'Berakhot' && i.level2 == '2')
          .toList();
      final result = groupItemsByNextLevel(
        items: daf2Items,
        currentDepth: 2,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level3).toSet(), {'a', 'b'});
      expect(result, hasLength(2));
    });
  });
}
