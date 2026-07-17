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
  // Bavli's level structure is Seder(1) > Masechta(2) > Daf(3) > Amud(4),
  // so this fixture exercises all four groupItemsByNextLevel depths (0-3).
  final items = [
    _item(
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: '2',
      level4: 'a',
      ref: 'Berakhot 2a',
      isLeaf: true,
      sortOrder: 1,
    ),
    _item(
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: '2',
      level4: 'b',
      ref: 'Berakhot 2b',
      isLeaf: true,
      sortOrder: 2,
    ),
    _item(
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: '3',
      level4: 'a',
      ref: 'Berakhot 3a',
      isLeaf: true,
      sortOrder: 3,
    ),
    _item(
      level1: 'Zeraim',
      level2: 'Shabbos',
      level3: '2',
      level4: 'a',
      ref: 'Shabbos 2a',
      isLeaf: true,
      sortOrder: 4,
    ),
    _item(
      level1: 'Moed',
      level2: 'Yoma',
      level3: '2',
      level4: 'a',
      ref: 'Yoma 2a',
      isLeaf: true,
      sortOrder: 5,
    ),
  ];

  group('groupItemsByNextLevel depth-to-level mapping', () {
    test('depth 0 groups by level1 (Seder)', () {
      final result = groupItemsByNextLevel(
        items: items,
        currentDepth: 0,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level1).toSet(), {'Zeraim', 'Moed'});
      expect(result, hasLength(2));
    });

    test('depth 1 groups by level2 (Masechta) within a Seder', () {
      final zeraimItems = items.where((i) => i.level1 == 'Zeraim').toList();
      final result = groupItemsByNextLevel(
        items: zeraimItems,
        currentDepth: 1,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level2).toSet(), {'Berakhot', 'Shabbos'});
      expect(result, hasLength(2));
    });

    test('depth 2 groups by level3 (Daf) within a Masechta', () {
      final berakhotItems = items.where((i) => i.level2 == 'Berakhot').toList();
      final result = groupItemsByNextLevel(
        items: berakhotItems,
        currentDepth: 2,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level3).toSet(), {'2', '3'});
      expect(result, hasLength(2));
    });

    test('depth 3 groups by level4 (Amud) within a Daf', () {
      final daf2Items = items
          .where((i) => i.level2 == 'Berakhot' && i.level3 == '2')
          .toList();
      final result = groupItemsByNextLevel(
        items: daf2Items,
        currentDepth: 3,
        curriculumId: CurriculumId.bavli,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(result.map((i) => i.level4).toSet(), {'a', 'b'});
      expect(result, hasLength(2));
    });
  });
}
