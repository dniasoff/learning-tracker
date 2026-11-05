// Regression coverage for ContentTree.fromCurricula's parent-resolution
// pass 2. AUD-core-content-02: when a leaf appears before its own container
// in source order, pass 1 cannot resolve its parent yet (the container
// isn't registered in containerByKey), so pass 2's fallback must fill it
// in. Pass 2 previously applied an extra "walk up one level" truncation to
// the leaf's already-resolved ancestor levels, landing on the grandparent
// container instead of the immediate parent.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

ContentItem _item({
  CurriculumId curriculumId = CurriculumId.bavli,
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required String ref,
  required bool isLeaf,
  String displayNameHe = '',
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: curriculumId.storageKey,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: displayNameHe,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

void main() {
  group('ContentTree.parent — leaf-before-container source order', () {
    test('resolves the immediate parent, not the grandparent, when a 4-level '
        'leaf precedes its own container in the input list', () {
      // Four-level Bavli-style hierarchy:
      //   Berakhot (l1) > 2 (l2, daf) > a (l3, amud, container) > 1 (l4, leaf)
      //
      // The leaf 'Berakhot 2a:1' is listed BEFORE its own container
      // 'Berakhot 2a', so pass 1 cannot resolve its parent (the container
      // isn't in containerByKey yet) and pass 2's fallback must do it.
      final leaf = _item(
        level1: 'Berakhot',
        level2: '2',
        level3: 'a',
        level4: '1',
        ref: 'Berakhot 2a:1',
        isLeaf: true,
        sortOrder: 1,
      );
      final amudContainer = _item(
        level1: 'Berakhot',
        level2: '2',
        level3: 'a',
        ref: 'Berakhot 2a',
        isLeaf: false,
        sortOrder: 0,
      );
      final dafContainer = _item(
        level1: 'Berakhot',
        level2: '2',
        ref: 'Berakhot 2',
        isLeaf: false,
        sortOrder: 0,
      );

      final tree = ContentTree.fromCurricula({
        CurriculumId.bavli: [
          // Leaf first, then its container, then the grandparent
          // container — deliberately out of parent-before-child order.
          leaf,
          amudContainer,
          dafContainer,
        ],
      });

      final parent = tree.parent('Berakhot 2a:1');

      expect(parent, isNotNull);
      expect(
        parent!.sefariaRef,
        equals('Berakhot 2a'),
        reason:
            'parent() must return the immediate parent container '
            '(Berakhot 2a), not the grandparent (Berakhot 2), regardless '
            'of source ordering',
      );
    });
  });

  test('Browse skips only a single self-named curriculum root', () {
    const curriculum = CurriculumId.mishnaBerurah;
    final root = _item(
      curriculumId: curriculum,
      level1: 'Mishnah Berurah',
      ref: 'Mishnah Berurah',
      isLeaf: false,
      displayNameHe: 'משנה ברורה',
    );
    final section = _item(
      curriculumId: curriculum,
      level1: 'Mishnah Berurah',
      level2: 'Shabbos',
      ref: 'Mishnah Berurah|section|Shabbos',
      isLeaf: false,
      sortOrder: 1,
    );
    final otherRoot = _item(level1: 'Berakhot', ref: 'Berakhot', isLeaf: false);
    final tree = ContentTree.fromCurricula({
      curriculum: [root, section],
      CurriculumId.bavli: [otherRoot],
    });

    expect(tree.browseStartStack(curriculum), ['Mishnah Berurah']);
    expect(tree.children(curriculum, tree.browseStartStack(curriculum)), [
      section,
    ]);
    expect(tree.browseStartStack(CurriculumId.bavli), isEmpty);
  });
}
