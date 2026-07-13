/// Regression coverage for the shared e2e test doubles in [FakeContentRepository]
/// and friends (AUD-t-cross-10).
///
/// Before this fix, `test/e2e/journeys/learning_p1_test.dart` hand-rolled its
/// own copy of `_FakeContentRepository` whose `filterByLevel` silently
/// ignored every level argument and returned the full unfiltered list —
/// diverging from `learning_p0_test.dart`'s copy, which filtered correctly.
/// This test exercises the single shared implementation directly so that
/// regression can never again go unnoticed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

import 'e2e_fakes.dart';

ContentItem _item({
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required String sefariaRef,
}) => ContentItem(
  curriculumId: CurriculumId.mishnayos.storageKey,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: sefariaRef,
  displayNameEn: sefariaRef,
  sefariaRef: sefariaRef,
  sortOrder: 0,
  isLeaf: true,
);

void main() {
  group('FakeContentRepository.filterByLevel', () {
    final zeraimBerachot = _item(
      level1: 'Seder Zeraim',
      level2: 'Berachot',
      sefariaRef: 'Mishnah_Berachot.1.1',
    );
    final zeraimPeah = _item(
      level1: 'Seder Zeraim',
      level2: 'Peah',
      sefariaRef: 'Mishnah_Peah.1.1',
    );
    final moedShabbat = _item(
      level1: 'Seder Moed',
      level2: 'Shabbat',
      sefariaRef: 'Mishnah_Shabbat.1.1',
    );

    late FakeContentRepository repo;

    setUp(() {
      repo = FakeContentRepository([zeraimBerachot, zeraimPeah, moedShabbat]);
    });

    test(
      'with no level filters, returns every item for the curriculum',
      () async {
        final result = await repo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(
          result,
          unorderedEquals([zeraimBerachot, zeraimPeah, moedShabbat]),
        );
      },
    );

    test(
      'filters by level1 — excludes items from a different level1',
      () async {
        final result = await repo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Seder Zeraim',
        );

        expect(result, unorderedEquals([zeraimBerachot, zeraimPeah]));
        expect(result, isNot(contains(moedShabbat)));
      },
    );

    test('filters by level1 + level2 — narrows to a single item', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Seder Zeraim',
        level2: 'Peah',
      );

      expect(result, equals([zeraimPeah]));
    });

    test('filters by level3 — narrows below level1/level2', () async {
      final chapter1 = _item(
        level1: 'Seder Zeraim',
        level2: 'Berachot',
        level3: 'Perek 1',
        sefariaRef: 'Mishnah_Berachot.1.1',
      );
      final chapter2 = _item(
        level1: 'Seder Zeraim',
        level2: 'Berachot',
        level3: 'Perek 2',
        sefariaRef: 'Mishnah_Berachot.2.1',
      );
      final level3Repo = FakeContentRepository([chapter1, chapter2]);

      final result = await level3Repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level3: 'Perek 1',
      );

      expect(result, equals([chapter1]));
    });

    test('filters by level4 — narrows below level1/level2/level3', () async {
      final mishna1 = _item(
        level1: 'Seder Zeraim',
        level2: 'Berachot',
        level3: 'Perek 1',
        level4: 'Mishna 1',
        sefariaRef: 'Mishnah_Berachot.1.1',
      );
      final mishna2 = _item(
        level1: 'Seder Zeraim',
        level2: 'Berachot',
        level3: 'Perek 1',
        level4: 'Mishna 2',
        sefariaRef: 'Mishnah_Berachot.1.2',
      );
      final level4Repo = FakeContentRepository([mishna1, mishna2]);

      final result = await level4Repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level4: 'Mishna 2',
      );

      expect(result, equals([mishna2]));
    });

    test('a level value that matches nothing returns an empty list (proves the '
        'filter is actually applied, not a pass-through)', () async {
      final result = await repo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: 'Seder Nashim',
      );

      expect(result, isEmpty);
    });
  });
}
