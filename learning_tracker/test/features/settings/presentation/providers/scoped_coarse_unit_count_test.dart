// Unit tests for [scopedCoarseUnitCountProvider] — the granularity-aware scope
// count used by the track-detail completion-date estimate.
//
// Regression guard for the FR fix: the track-detail "Est. finish" used to divide
// the LEAF count (amudim) by a daf-per-week rate, doubling the projected
// timeline vs the add-track wizard. The coarse count must collapse leaves to
// their parent (the daf/perek/seif unit) so a pace goal measured in coarse units
// divides by the right number.

@Tags(['tracks'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';

ContentItem _leaf({
  required String level1,
  required String level2,
  required String level3,
  String? level4,
  required String ref,
}) => ContentItem(
  curriculumId: 'bavli',
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: '',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: true,
);

Future<ProviderContainer> _containerWith(List<ContentItem> content) async {
  return ProviderContainer(
    overrides: [
      scopedCurriculumContentProvider(
        CurriculumId.bavli,
      ).overrideWith((ref) async => content),
    ],
  );
}

void main() {
  group('scopedCoarseUnitCountProvider', () {
    test(
      'Talmud: collapses amudim (level4 leaves) to distinct dapim (l1|l2|l3)',
      () async {
        // 2 dapim × 2 amudim each = 4 leaves, but only 2 coarse units (dapim).
        final leaves = [
          _leaf(
            level1: 'Zeraim',
            level2: 'Berakhos',
            level3: '2',
            level4: 'a',
            ref: 'Berakhos 2a',
          ),
          _leaf(
            level1: 'Zeraim',
            level2: 'Berakhos',
            level3: '2',
            level4: 'b',
            ref: 'Berakhos 2b',
          ),
          _leaf(
            level1: 'Zeraim',
            level2: 'Berakhos',
            level3: '3',
            level4: 'a',
            ref: 'Berakhos 3a',
          ),
          _leaf(
            level1: 'Zeraim',
            level2: 'Berakhos',
            level3: '3',
            level4: 'b',
            ref: 'Berakhos 3b',
          ),
        ];
        final container = await _containerWith(leaves);
        addTearDown(container.dispose);

        final coarse = await container.read(
          scopedCoarseUnitCountProvider(CurriculumId.bavli).future,
        );
        final leafCount = await container.read(
          scopedItemCountProvider(CurriculumId.bavli).future,
        );

        expect(leafCount, 4, reason: '4 amudim');
        expect(coarse, 2, reason: '2 distinct dapim (Berakhos 2, Berakhos 3)');
      },
    );

    test(
      'Chumash-style: collapses pesukim (level3 leaves) to distinct perakim',
      () async {
        // level3 leaves (no level4): parent key is l1|l2 (sefer|perek).
        final leaves = [
          _leaf(level1: 'Bereishis', level2: '1', level3: '1', ref: 'Gen 1:1'),
          _leaf(level1: 'Bereishis', level2: '1', level3: '2', ref: 'Gen 1:2'),
          _leaf(level1: 'Bereishis', level2: '2', level3: '1', ref: 'Gen 2:1'),
        ];
        final container = await _containerWith(leaves);
        addTearDown(container.dispose);

        final coarse = await container.read(
          scopedCoarseUnitCountProvider(CurriculumId.bavli).future,
        );
        expect(coarse, 2, reason: '2 distinct perakim (Bereishis 1, 2)');
      },
    );

    test('ignores non-leaf container rows', () async {
      final container = await _containerWith([
        const ContentItem(
          curriculumId: 'bavli',
          level1: 'Zeraim',
          level2: 'Berakhos',
          level3: null,
          level4: null,
          displayNameHe: '',
          displayNameEn: 'Berakhos',
          sefariaRef: 'Berakhos',
          sortOrder: 0,
          isLeaf: false,
        ),
        _leaf(
          level1: 'Zeraim',
          level2: 'Berakhos',
          level3: '2',
          level4: 'a',
          ref: 'Berakhos 2a',
        ),
      ]);
      addTearDown(container.dispose);

      final coarse = await container.read(
        scopedCoarseUnitCountProvider(CurriculumId.bavli).future,
      );
      expect(coarse, 1, reason: 'one daf; the non-leaf folder row is skipped');
    });
  });
}
