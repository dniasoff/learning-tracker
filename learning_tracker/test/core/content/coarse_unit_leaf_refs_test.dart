// Tests for the daf-atomic completion helpers: coarseUnitKeyForItem +
// coarseUnitLeafRefs. These resolve a leaf's coarse unit (the daf for Bavli)
// and all sibling leaves, so one mark can complete the whole daf.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
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
  group('coarseUnitKeyForItem', () {
    test('Bavli 3-level leaf (amud) keys on Masechta|Daf', () {
      final amud = _item(
        level1: 'Berakhot',
        level2: '2',
        level3: 'a',
        ref: 'Berakhot 2a',
        isLeaf: true,
      );
      expect(coarseUnitKeyForItem(amud), 'Berakhot${kScopeIdSeparator}2');
    });

    test('4-level leaf (mishna/pasuk) keys on the perek (l1|l2|l3)', () {
      final mishna = _item(
        level1: 'Seder Zeraim',
        level2: 'Berakhos',
        level3: '1',
        level4: '1',
        ref: 'Berakhos 1:1',
        isLeaf: true,
      );
      expect(
        coarseUnitKeyForItem(mishna),
        'Seder Zeraim${kScopeIdSeparator}Berakhos${kScopeIdSeparator}1',
      );
    });
  });

  group('coarseUnitLeafRefs (Bavli daf = both amudim)', () {
    // Berakhot daf 2 (2a, 2b) and daf 3 (3a, 3b), plus folder rows.
    final items = [
      _item(level1: 'Berakhot', ref: 'Berakhot', isLeaf: false),
      _item(level1: 'Berakhot', level2: '2', ref: 'Berakhot 2', isLeaf: false),
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
        level1: 'Berakhot',
        level2: '3',
        level3: 'b',
        ref: 'Berakhot 3b',
        isLeaf: true,
        sortOrder: 4,
      ),
    ];

    test('returns both amudim of the daf, in order, from either amud', () {
      expect(coarseUnitLeafRefs(items, 'Berakhot 2a'), [
        'Berakhot 2a',
        'Berakhot 2b',
      ]);
      // From the 2nd amud you still get the whole daf.
      expect(coarseUnitLeafRefs(items, 'Berakhot 2b'), [
        'Berakhot 2a',
        'Berakhot 2b',
      ]);
    });

    test('does not bleed into the adjacent daf', () {
      final refs = coarseUnitLeafRefs(items, 'Berakhot 2a');
      expect(refs.contains('Berakhot 3a'), isFalse);
      expect(refs.contains('Berakhot 3b'), isFalse);
    });

    test('a single-amud daf returns just that one amud (still a daf)', () {
      final oneAmud = [
        _item(
          level1: 'Tamid',
          level2: '25',
          level3: 'b',
          ref: 'Tamid 25b',
          isLeaf: true,
        ),
      ];
      expect(coarseUnitLeafRefs(oneAmud, 'Tamid 25b'), ['Tamid 25b']);
    });

    test('unknown ref returns itself alone', () {
      expect(coarseUnitLeafRefs(items, 'Nope 9z'), ['Nope 9z']);
    });
  });
}
