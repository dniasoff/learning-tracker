// Regression test for R5-6 (docs/planning/bug-hunt-round5-findings-2026-05-31.md):
// the browse tree showed "No content" instead of the terminal chapter rows
// when the navigation stack landed exactly at `maxBrowseDepth` (e.g. via a
// deep-link URL that pre-fills every level). The bug was fixed in
// content_hierarchy_screen.dart's private, hand-duplicated grouping helper
// but never ported back to this shared `groupItemsByNextLevel` — which still
// had the pre-fix `if (currentDepth >= maxBrowseDepth) return const [];`
// guard. AUD-core-content-04.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

import '../../fixtures/content_fixtures.dart';

ContentItem _leaf({
  required String level3,
  required String level4,
  required int sortOrder,
}) => ContentItemFixtures.leaf(
  curriculumId: 'mishnayos',
  level1: 'Seder Zeraim',
  level2: 'Berachos',
  level3: level3,
  level4: level4,
  sefariaRef: 'Mishnah Berakhot $level3.$level4',
  sortOrder: sortOrder,
  displayNameHe: 'משנה $level3:$level4',
  displayNameEn: 'Mishnah $level3:$level4',
);

void main() {
  group('groupItemsByNextLevel — maxBrowseDepth clamp (R5-6 regression)', () {
    test('currentDepth == maxBrowseDepth returns clamped terminal-level rows, '
        'not an empty list', () {
      final maxDepth = CurriculumLabels.maxBrowseDepth(CurriculumId.mishnayos);
      // Sanity on the fixture: Mishnayos browse stops at Perek (depth 3).
      expect(maxDepth, 3);

      // Two pereks (level3 '1' and '2'), each with leaf mishnayos (level4).
      final items = [
        _leaf(level3: '1', level4: '1', sortOrder: 0),
        _leaf(level3: '1', level4: '2', sortOrder: 1),
        _leaf(level3: '2', level4: '1', sortOrder: 2),
      ];

      // Simulates a deep-link that lands the navigation stack exactly at
      // maxBrowseDepth (currentDepth == maxBrowseDepth == 3).
      final result = groupItemsByNextLevel(
        items: items,
        currentDepth: maxDepth,
        curriculumId: CurriculumId.mishnayos,
        variant: TransliterationVariant.ashkenazi,
        maxBrowseDepth: maxDepth,
      );

      // Must NOT be the pre-fix `return const []` — the effective grouping
      // depth must clamp to (maxBrowseDepth - 1) so the perek-level rows
      // still render instead of an empty "No content" state.
      expect(
        result,
        isNot(isEmpty),
        reason:
            'R5-6: at currentDepth == maxBrowseDepth the function must '
            'still return the clamped terminal-level rows, not []',
      );
      expect(result.length, 2);
      expect(result.map((i) => i.level3).toList(), ['1', '2']);
    });

    test(
      'currentDepth beyond maxBrowseDepth also clamps rather than emptying',
      () {
        final maxDepth = CurriculumLabels.maxBrowseDepth(
          CurriculumId.mishnayos,
        );
        final items = [_leaf(level3: '1', level4: '1', sortOrder: 0)];

        final result = groupItemsByNextLevel(
          items: items,
          currentDepth: maxDepth + 1,
          curriculumId: CurriculumId.mishnayos,
          variant: TransliterationVariant.ashkenazi,
          maxBrowseDepth: maxDepth,
        );

        expect(result, isNot(isEmpty));
      },
    );

    test('currentDepth below maxBrowseDepth is unaffected by the clamp', () {
      final maxDepth = CurriculumLabels.maxBrowseDepth(CurriculumId.mishnayos);
      final items = [
        _leaf(level3: '1', level4: '1', sortOrder: 0),
        _leaf(level3: '2', level4: '1', sortOrder: 1),
      ];

      // currentDepth 1 (grouping by level2 / masechta) is well under
      // maxBrowseDepth 3 — behaves exactly as the uncapped case.
      final result = groupItemsByNextLevel(
        items: items,
        currentDepth: 1,
        curriculumId: CurriculumId.mishnayos,
        variant: TransliterationVariant.ashkenazi,
        maxBrowseDepth: maxDepth,
      );

      expect(result.length, 1); // both items share level2 'Berachos'
      expect(result.single.level2, 'Berachos');
    });
  });
}
